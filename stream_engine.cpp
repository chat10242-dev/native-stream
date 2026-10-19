#include "stream_engine.hpp"

#include <arpa/inet.h>
#include <cerrno>
#include <csignal>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <iostream>
#include <algorithm>
#include <linux/input.h>
#include <linux/uinput.h>
#include <netinet/in.h>
#include <poll.h>
#include <string>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <thread>
#include <set>
#include <chrono>
#include <unistd.h>
#include <vector>

namespace {
constexpr uint32_t kMagic = 0x4e535452; // NSTR
constexpr uint16_t kVersion = 1;
constexpr size_t kChunk = 1100; // Keep UDP packets below common path MTUs.
volatile sig_atomic_t gStop = 0;

struct PacketHeader {
    uint32_t magic;
    uint32_t sequence;
    uint16_t version;
    uint16_t part;
    uint16_t parts;
    uint16_t reserved;
};

void stopHandler(int) { gStop = 1; }

bool parsePort(const char* text, uint16_t& port) {
    try {
        size_t used = 0;
        const unsigned long n = std::stoul(text, &used);
        if (used != std::strlen(text) || n == 0 || n > 65534) return false;
        port = static_cast<uint16_t>(n);
        return true;
    } catch (...) { return false; }
}

struct __attribute__((packed)) InputPacket {
    uint32_t magic;
    uint8_t type; // 1 key, 2 mouse button, 3 relative mouse movement
    uint8_t down;
    uint16_t code;
    int32_t x;
    int32_t y;
};

void emitInput(int fd, uint16_t type, uint16_t code, int32_t value) {
    input_event ev{}; gettimeofday(&ev.time, nullptr); ev.type=type; ev.code=code; ev.value=value;
    (void)::write(fd, &ev, sizeof(ev));
}

void inputReceiver(uint16_t port, std::string pin) {
    int device=::open("/dev/uinput",O_WRONLY|O_NONBLOCK);
    if(device<0){std::cerr<<"Controlli remoti disattivati: apri /dev/uinput con i permessi del tuo utente.\n";return;}
    ::ioctl(device,UI_SET_EVBIT,EV_SYN);::ioctl(device,UI_SET_EVBIT,EV_KEY);::ioctl(device,UI_SET_EVBIT,EV_REL);
    for(int code=0;code<=KEY_MAX;code++)::ioctl(device,UI_SET_KEYBIT,code);
    ::ioctl(device,UI_SET_RELBIT,REL_X);::ioctl(device,UI_SET_RELBIT,REL_Y);
    uinput_setup setup{}; setup.id.bustype=BUS_USB;setup.id.vendor=0x1209;setup.id.product=0x4e53;
    std::strncpy(setup.name,"NativeStream Game Touch",UINPUT_MAX_NAME_SIZE-1);
    if(::ioctl(device,UI_DEV_SETUP,&setup)<0||::ioctl(device,UI_DEV_CREATE)<0){std::perror("uinput setup");::close(device);return;}
    const int sock=::socket(AF_INET,SOCK_DGRAM,0);
    if(sock<0){::ioctl(device,UI_DEV_DESTROY);::close(device);return;}
    sockaddr_in local{};local.sin_family=AF_INET;local.sin_addr.s_addr=htonl(INADDR_ANY);local.sin_port=htons(port);
    if(::bind(sock,reinterpret_cast<sockaddr*>(&local),sizeof(local))<0){std::perror("bind input");::close(sock);::ioctl(device,UI_DEV_DESTROY);::close(device);return;}
    pollfd pfd{sock,POLLIN,0};
    sockaddr_in peer{},authorizedPeer{};socklen_t peerLen=sizeof(peer);bool paired=false;
    std::vector<uint8_t> buf(256);
    std::set<uint16_t> downKeys,downButtons;
    const std::string expectedHello="NSINPUT:"+pin;
    auto lastSeen=std::chrono::steady_clock::now();
    while(!gStop){int ready=::poll(&pfd,1,300);if(ready<=0){if(paired&&std::chrono::steady_clock::now()-lastSeen>std::chrono::seconds(4)){for(uint16_t k:downKeys)emitInput(device,EV_KEY,k,0);for(uint16_t k:downButtons)emitInput(device,EV_KEY,k,0);emitInput(device,EV_SYN,SYN_REPORT,0);downKeys.clear();downButtons.clear();paired=false;}continue;}
        const ssize_t n=::recvfrom(sock,buf.data(),buf.size(),0,reinterpret_cast<sockaddr*>(&peer),&peerLen);if(n<=0)continue;
        if(!paired){if(static_cast<size_t>(n)!=expectedHello.size()||std::memcmp(buf.data(),expectedHello.data(),expectedHello.size())!=0)continue;authorizedPeer=peer;lastSeen=std::chrono::steady_clock::now();paired=true;std::cerr<<"Canale comandi collegato (non cifrato).\n";continue;}
        if(peer.sin_addr.s_addr!=authorizedPeer.sin_addr.s_addr||peer.sin_port!=authorizedPeer.sin_port)continue;
        lastSeen=std::chrono::steady_clock::now();
        if(static_cast<size_t>(n)==expectedHello.size()&&std::memcmp(buf.data(),expectedHello.data(),expectedHello.size())==0)continue;
        InputPacket packet{};if(n!=static_cast<ssize_t>(sizeof(packet)))continue;std::memcpy(&packet,buf.data(),sizeof(packet));
        if(ntohl(packet.magic)!=0x4e53494e)continue;
        const uint16_t code=ntohs(packet.code);const int32_t x=static_cast<int32_t>(ntohl(static_cast<uint32_t>(packet.x)));const int32_t y=static_cast<int32_t>(ntohl(static_cast<uint32_t>(packet.y)));
        if(packet.type==5){for(uint16_t k:downKeys)emitInput(device,EV_KEY,k,0);for(uint16_t k:downButtons)emitInput(device,EV_KEY,k,0);downKeys.clear();downButtons.clear();emitInput(device,EV_SYN,SYN_REPORT,0);}
        else if(packet.type==1&&code<=KEY_MAX){emitInput(device,EV_KEY,code,packet.down?1:0);if(packet.down)downKeys.insert(code);else downKeys.erase(code);emitInput(device,EV_SYN,SYN_REPORT,0);}
        else if(packet.type==2&&(code==BTN_LEFT||code==BTN_RIGHT)){emitInput(device,EV_KEY,code,packet.down?1:0);if(packet.down)downButtons.insert(code);else downButtons.erase(code);emitInput(device,EV_SYN,SYN_REPORT,0);}
        else if(packet.type==3){const int32_t mx=std::max(-2000,std::min(2000,x)),my=std::max(-2000,std::min(2000,y));if(mx)emitInput(device,EV_REL,REL_X,mx);if(my)emitInput(device,EV_REL,REL_Y,my);emitInput(device,EV_SYN,SYN_REPORT,0);}
        else if(packet.type==4){
            const uint16_t* keys=nullptr;const uint16_t wasd[]={KEY_W,KEY_A,KEY_S,KEY_D};const uint16_t arrows[]={KEY_UP,KEY_LEFT,KEY_DOWN,KEY_RIGHT};const uint16_t ijkl[]={KEY_I,KEY_J,KEY_K,KEY_L};
            if(code==1)keys=arrows;else if(code==2)keys=ijkl;else keys=wasd;
            const bool wanted[]={y < -350,x < -350,y > 350,x > 350};
            for(int i=0;i<4;i++){bool held=downKeys.count(keys[i])!=0;if(wanted[i]&&!held){emitInput(device,EV_KEY,keys[i],1);downKeys.insert(keys[i]);}else if(!wanted[i]&&held){emitInput(device,EV_KEY,keys[i],0);downKeys.erase(keys[i]);}}
            emitInput(device,EV_SYN,SYN_REPORT,0);
        }
    }
    for(uint16_t k:downKeys) emitInput(device,EV_KEY,k,0);
    for(uint16_t k:downButtons) emitInput(device,EV_KEY,k,0);
    emitInput(device,EV_SYN,SYN_REPORT,0);
    ::close(sock);::ioctl(device,UI_DEV_DESTROY);::close(device);
}

int spawnFfmpeg(const std::vector<std::string>& args, int inputFd, int outputFd) {
    const pid_t child = ::fork();
    if (child == 0) {
        if (inputFd >= 0 && ::dup2(inputFd, STDIN_FILENO) < 0) _exit(126);
        if (outputFd >= 0 && ::dup2(outputFd, STDOUT_FILENO) < 0) _exit(126);
        const int nullfd = ::open("/dev/null", O_WRONLY);
        if (nullfd >= 0) { ::dup2(nullfd, STDERR_FILENO); ::close(nullfd); }
        std::vector<char*> argv;
        argv.reserve(args.size() + 1);
        for (const auto& arg : args) argv.push_back(const_cast<char*>(arg.c_str()));
        argv.push_back(nullptr);
        ::execvp(argv[0], argv.data());
        _exit(127);
    }
    return child < 0 ? -1 : static_cast<int>(child);
}

int host(const char* portText, const char* pin) {
    gStop=0;
    uint16_t port = 0;
    if (!parsePort(portText, port)) { std::cerr << "Porta non valida.\n"; return 2; }
    int pipefd[2];
    if (::pipe(pipefd) < 0) { std::perror("pipe"); return 1; }
    const std::vector<std::string> ffmpeg = {
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "x11grab",
        "-framerate", "30", "-video_size", "1280x720", "-i", ":0.0",
        "-an", "-c:v", "libx264", "-preset", "ultrafast", "-tune", "zerolatency",
        "-pix_fmt", "yuv420p", "-g", "30", "-f", "h264", "pipe:1"
    };
    const int encoder = spawnFfmpeg(ffmpeg, -1, pipefd[1]);
    ::close(pipefd[1]);
    if (encoder < 0) { ::close(pipefd[0]); std::perror("fork"); return 1; }

    const int sock = ::socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) { ::close(pipefd[0]); ::kill(encoder, SIGTERM); std::perror("socket"); return 1; }
    timeval handshakeTimeout{1, 0};
    ::setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &handshakeTimeout, sizeof(handshakeTimeout));
    sockaddr_in local{};
    local.sin_family = AF_INET;
    local.sin_addr.s_addr = htonl(INADDR_ANY);
    local.sin_port = htons(port);
    if (::bind(sock, reinterpret_cast<sockaddr*>(&local), sizeof(local)) < 0) {
        ::close(sock); ::close(pipefd[0]); ::kill(encoder, SIGTERM); std::perror("bind"); return 1;
    }
    std::thread inputs(inputReceiver,static_cast<uint16_t>(port+1),std::string(pin));
    std::signal(SIGINT, stopHandler);
    std::signal(SIGTERM, stopHandler);
    std::cout << "Attendo client UDP sulla porta " << port
              << " (IP raggiungibile; flusso non cifrato: usa solo rete fidata/VPN).\n" << std::flush;
    const std::string expected = std::string("NATIVE1:") + pin;
    sockaddr_in peer{};socklen_t peerLen=sizeof(peer);uint8_t hello[128];bool paired=false;
    while(!gStop){peerLen=sizeof(peer);const ssize_t helloLen=::recvfrom(sock,hello,sizeof(hello),0,reinterpret_cast<sockaddr*>(&peer),&peerLen);
        if(helloLen<0&&(errno==EAGAIN||errno==EWOULDBLOCK||errno==EINTR))continue;
        if(helloLen==static_cast<ssize_t>(expected.size())&&std::memcmp(hello,expected.data(),expected.size())==0){paired=true;break;}
    }
    if(!paired){gStop=1;inputs.join();::close(sock);::close(pipefd[0]);::kill(encoder,SIGTERM);return 1;
    }
    const char* ok = "NATIVE1:OK";
    ::sendto(sock, ok, std::strlen(ok), 0, reinterpret_cast<sockaddr*>(&peer), peerLen);
    std::cerr << "Client collegato: " << inet_ntoa(peer.sin_addr) << ". Ctrl+C per fermare.\n";

    uint32_t sequence = 0;
    uint8_t buf[8192];
    while (!gStop) {
        pollfd pfd{pipefd[0], POLLIN | POLLHUP, 0};
        const int ready = ::poll(&pfd, 1, 200);
        if (ready < 0 && errno == EINTR) continue;
        if (ready <= 0) continue;
        const ssize_t n = ::read(pipefd[0], buf, sizeof(buf));
        if (n <= 0) break;
        for (ssize_t off = 0; off < n; off += static_cast<ssize_t>(kChunk)) {
            const size_t count = std::min(kChunk, static_cast<size_t>(n - off));
            PacketHeader h{htonl(kMagic), htonl(sequence++), htons(kVersion), htons(0), htons(1), 0};
            uint8_t packet[sizeof(h) + kChunk];
            std::memcpy(packet, &h, sizeof(h));
            std::memcpy(packet + sizeof(h), buf + off, count);
            ::sendto(sock, packet, sizeof(h) + count, 0, reinterpret_cast<sockaddr*>(&peer), peerLen);
        }
    }
    gStop=1;inputs.join();::close(sock); ::close(pipefd[0]); ::kill(encoder, SIGTERM); ::waitpid(encoder, nullptr, 0);
    return 0;
}

int client(const char* address, const char* portText, const char* pin) {
    uint16_t port = 0;
    if (!parsePort(portText, port)) { std::cerr << "Porta non valida.\n"; return 2; }
    int pipefd[2];
    if (::pipe(pipefd) < 0) { std::perror("pipe"); return 1; }
    const std::vector<std::string> playerArgs = {"ffplay", "-hide_banner", "-loglevel", "error", "-fflags", "nobuffer", "-flags", "low_delay", "-f", "h264", "pipe:0"};
    const int player = spawnFfmpeg(playerArgs, pipefd[0], -1);
    ::close(pipefd[0]);
    if (player < 0) { ::close(pipefd[1]); std::perror("fork"); return 1; }
    int sock = ::socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) { ::close(pipefd[1]); ::kill(player, SIGTERM); ::perror("socket"); return 1; }
    timeval handshakeTimeout{10, 0};
    ::setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &handshakeTimeout, sizeof(handshakeTimeout));
    sockaddr_in hostAddr{};
    hostAddr.sin_family = AF_INET;
    hostAddr.sin_port = htons(port);
    if (::inet_pton(AF_INET, address, &hostAddr.sin_addr) != 1) {
        std::cerr << "Indirizzo IPv4 non valido.\n"; ::close(sock); ::close(pipefd[1]); ::kill(player, SIGTERM); return 2;
    }
    if (::connect(sock, reinterpret_cast<sockaddr*>(&hostAddr), sizeof(hostAddr)) < 0) {
        ::perror("connect UDP"); ::close(sock); ::close(pipefd[1]); ::kill(player, SIGTERM); return 1;
    }
    const std::string hello = std::string("NATIVE1:") + pin;
    if (::send(sock, hello.data(), hello.size(), 0) < 0) {
        ::perror("sendto"); ::close(sock); ::close(pipefd[1]); ::kill(player, SIGTERM); return 1;
    }
    uint8_t packet[sizeof(PacketHeader) + kChunk];
    const ssize_t helloLen = ::recv(sock, packet, sizeof(packet), 0);
    if (helloLen != 10 || std::memcmp(packet, "NATIVE1:OK", 10) != 0) {
        std::cerr << "Handshake fallito o timeout: controlla host, porta e PIN.\n";
        ::close(sock); ::close(pipefd[1]); ::kill(player, SIGTERM); ::waitpid(player, nullptr, 0); return 1;
    }
    std::signal(SIGINT, stopHandler);
    std::signal(SIGTERM, stopHandler);
    std::cerr << "Ricezione video attiva. Ctrl+C per fermare.\n";
    uint32_t expectedSequence = 0;
    while (!gStop) {
        pollfd pfd{sock, POLLIN, 0};
        const int ready = ::poll(&pfd, 1, 200);
        if (ready < 0 && errno == EINTR) continue;
        if (ready <= 0) continue;
        const ssize_t n = ::recv(sock, packet, sizeof(packet), 0);
        if (n <= static_cast<ssize_t>(sizeof(PacketHeader))) continue;
        PacketHeader h{};
        std::memcpy(&h, packet, sizeof(h));
        if (ntohl(h.magic) != kMagic || ntohs(h.version) != kVersion) continue;
        const uint32_t seq = ntohl(h.sequence);
        if (seq != expectedSequence) {
            expectedSequence = seq; // UDP loss: resume at next packet; decoder will resync at an IDR.
        }
        const size_t payload = static_cast<size_t>(n) - sizeof(PacketHeader);
        const uint8_t* data = packet + sizeof(PacketHeader);
        size_t offset = 0;
        while (offset < payload) {
            const ssize_t written = ::write(pipefd[1], data + offset, payload - offset);
            if (written < 0 && errno == EINTR) continue;
            if (written <= 0) { gStop = 1; break; }
            offset += static_cast<size_t>(written);
        }
        expectedSequence = seq + 1;
    }
    ::close(sock); ::close(pipefd[1]); ::kill(player, SIGTERM); ::waitpid(player, nullptr, 0);
    return 0;
}
} // namespace

int runStreamEngine(int argc, char** argv) {
    std::signal(SIGPIPE, SIG_IGN);
    if (argc >= 2 && std::strcmp(argv[1], "--host") == 0) {
        if (argc != 4) { std::cerr << "Uso: native-stream-studio --host PORTA PIN\n"; return 2; }
        return host(argv[2], argv[3]);
    }
    if (argc >= 2 && std::strcmp(argv[1], "--client") == 0) {
        if (argc != 5) { std::cerr << "Uso: native-stream-studio --client IP PORTA PIN\n"; return 2; }
        return client(argv[2], argv[3], argv[4]);
    }
    return -1;
}
