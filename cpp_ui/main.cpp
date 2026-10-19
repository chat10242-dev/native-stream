#include <cerrno>
#include <cstring>
#include <iostream>
#include <string>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

namespace {
constexpr const char* kClear = "\033[2J\033[H";
constexpr const char* kPanel =
    "NativeStream ASM\n"
    "+----------------------------------------+\n"
    "|  [1] Host       [2] Client            |\n"
    "|  [3] Profile    [4] Remote           |\n"
    "|  [5] Exit                             |\n"
    "+----------------------------------------+\n"
    "> ";

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
    std::string path(buffer);
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
    for (const auto& candidate : candidates) {
        if (!candidate.empty() && ::access(candidate.c_str(), X_OK) == 0)
            return candidate;
    }
    return {};
}

bool launchEngine(const std::string& mode) {
    const std::string engine = resolveEngine();
    if (engine.empty()) {
        std::cerr << "Motore assembly non trovato. Reinstalla native-stream o compila il progetto.\n";
        return false;
    }
    const pid_t child = ::fork();
    if (child == 0) {
        ::execl(engine.c_str(), engine.c_str(), mode.c_str(), static_cast<char*>(nullptr));
        const int error = errno;
        std::cerr << "Avvio del motore non riuscito: " << std::strerror(error) << '\n';
        _exit(127);
    }
    if (child < 0) {
        std::cerr << "Creazione del processo non riuscita: " << std::strerror(errno) << '\n';
        return false;
    }
    int status = 0;
    pid_t result;
    do {
        result = ::waitpid(child, &status, 0);
    } while (result < 0 && errno == EINTR);
    if (result < 0) {
        std::cerr << "Attesa del motore non riuscita: " << std::strerror(errno) << '\n';
        return false;
    }
    return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}
}  // namespace

int main() {
    for (;;) {
        std::cout << kClear << kPanel << std::flush;
        std::string choice;
        if (!readChoice(choice)) {
            std::cout << '\n';
            return 0;
        }
        if (choice == "1") launchEngine("--host");
        else if (choice == "2") launchEngine("--client");
        else if (choice == "3") launchEngine("--profile");
        else if (choice == "4") launchEngine("--remote");
        else if (choice == "5") {
            std::cout << kClear << "NativeStream closed.\n";
            return 0;
        } else {
            std::cout << "Scelta non valida. Premi Invio per continuare..." << std::flush;
            std::string ignored;
            if (!readChoice(ignored)) return 0;
        }
    }
}
