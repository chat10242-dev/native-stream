#include <cerrno>
#include <cstring>
#include <iostream>
#include <string>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

namespace {
constexpr const char* kReset = "\033[0m";
constexpr const char* kBold = "\033[1m";
constexpr const char* kCyan = "\033[96m";
constexpr const char* kBlue = "\033[94m";
constexpr const char* kGreen = "\033[92m";
constexpr const char* kYellow = "\033[93m";
constexpr const char* kMagenta = "\033[95m";
constexpr const char* kRed = "\033[91m";
constexpr const char* kClear = "\033[2J\033[H";

bool readChoice(std::string& line) {
    line.clear();
    char ch = 0;
    for (;;) {
        const ssize_t n = ::read(STDIN_FILENO, &ch, 1);
        if (n == 0) return !line.empty();
        if (n < 0) {
            if (errno == EINTR) continue;
            return false;
        }
        if (ch == '\n') return true;
        if (ch != '\r' && line.size() < 32) line.push_back(ch);
    }
}

std::string executableDirectory() {
    char buffer[4096];
    const ssize_t n = ::readlink("/proc/self/exe", buffer, sizeof(buffer) - 1);
    if (n < 0) return {};
    buffer[n] = '\0';
    const std::string path(buffer);
    const auto slash = path.find_last_of('/');
    return slash == std::string::npos ? std::string(".") : path.substr(0, slash);
}

std::string resolveEngine() {
    const std::string dir = executableDirectory();
    const std::vector<std::string> candidates = {
        "/usr/lib/native-stream/native_stream_asm",
        "/usr/bin/native_stream_asm",
        "/usr/local/bin/native_stream_asm",
        dir + "/../main",
        dir + "/native_stream_asm",
        "./main",
    };
    for (const auto& candidate : candidates)
        if (!candidate.empty() && ::access(candidate.c_str(), X_OK) == 0) return candidate;
    return {};
}

bool launchEngine(const std::string& mode) {
    const std::string engine = resolveEngine();
    if (engine.empty()) {
        std::cerr << kRed << "Assembly engine not found. Install native-stream-asm." << kReset << '\n';
        return false;
    }
    const pid_t child = ::fork();
    if (child == 0) {
        ::execl(engine.c_str(), engine.c_str(), mode.c_str(), static_cast<char*>(nullptr));
        const int error = errno;
        std::cerr << kRed << "Could not start assembly engine: " << std::strerror(error) << kReset << '\n';
        _exit(127);
    }
    if (child < 0) {
        std::cerr << kRed << "Could not launch engine: " << std::strerror(errno) << kReset << '\n';
        return false;
    }
    int status = 0;
    pid_t result;
    do { result = ::waitpid(child, &status, 0); } while (result < 0 && errno == EINTR);
    if (result < 0) {
        std::cerr << kRed << "Could not wait for engine: " << std::strerror(errno) << kReset << '\n';
        return false;
    }
    return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

void printCapabilities() {
    std::cout << kClear << kBold << kCyan << "NATIVE STREAM | PANORAMICA" << kReset << "\n\n";
    std::cout << kGreen << "COSA PUO FARE" << kReset << '\n'
              << "  • Salvare fino a tre percorsi di eseguibili.\n"
              << "  • Mostrare e selezionare un percorso configurato.\n"
              << "  • Creare profili di controllo con nome e comandi.\n"
              << "  • Salvare una preferenza di connessione LAN, diretta o relay.\n\n";
    std::cout << kRed << "COSA NON FA ANCORA" << kReset << '\n'
              << "  • Non cattura, codifica o trasmette video e audio.\n"
              << "  • Non invia input remoto e non apre connessioni di rete.\n"
              << "  • La selezione client mostra il percorso, non avvia lo streaming.\n"
              << "  • LAN, Internet e relay sono preferenze salvate, non connessioni reali.\n\n";
    std::cout << kYellow << "COSA LO DISTINGUE" << kReset << '\n'
              << "  • Il motore x86_64 Linux e scritto in assembly e usa syscall native.\n"
              << "  • La variante ASM offre un menu essenziale senza interfaccia C++.\n"
              << "  • Studio aggiunge questa guida e un pannello terminale a colori.\n\n";
    std::cout << "Motore: assembly x86_64 | Frontend Studio: C++ | Rete: non implementata\n\n"
              << "Premi Invio per tornare al menu..." << std::flush;
    std::string ignored;
    readChoice(ignored);
}

void drawMenu() {
    std::cout << kClear << kBold << kCyan
              << "============================================================\n"
              << "                  NATIVESTREAM STUDIO\n"
              << "       Terminal Control Center | Assembly Core\n"
              << "============================================================\n" << kReset;
    std::cout << kBlue << "+----------------------------------------------------------+\n"
              << "|  [1] Host setup          Configure executable paths     |\n"
              << "|  [2] Client              Browse saved entries           |\n"
              << "|  [3] Control profiles    Create and view bindings       |\n"
              << "|  [4] Remote preferences  Save a connection strategy     |\n"
              << "|  [5] Capabilities        What works and what does not   |\n"
              << "|  [6] Exit                                               |\n"
              << "+----------------------------------------------------------+\n" << kReset;
    std::cout << kMagenta << "Engine: x86_64 assembly   " << kYellow
              << "Streaming/network: not implemented\n" << kReset;
    std::cout << kBold << "Select option > " << kReset << std::flush;
}
}  // namespace

int main() {
    for (;;) {
        drawMenu();
        std::string choice;
        if (!readChoice(choice)) { std::cout << '\n'; return 0; }
        if (choice == "1") launchEngine("--host");
        else if (choice == "2") launchEngine("--client");
        else if (choice == "3") launchEngine("--profile");
        else if (choice == "4") launchEngine("--remote");
        else if (choice == "5") printCapabilities();
        else if (choice == "6") {
            std::cout << kClear << kBold << kGreen << "NativeStream Studio closed." << kReset << '\n';
            return 0;
        } else {
            std::cout << kRed << "Invalid choice. Press Enter to continue..." << kReset << std::flush;
            std::string ignored;
            if (!readChoice(ignored)) return 0;
        }
    }
}
