# NativeStream

NativeStream is a prototype for Debian/Ubuntu amd64 with two terminal interfaces that share one x86_64 Linux assembly engine:

- `native-stream-asm`: minimal standalone menu and engine in assembly.
- `native-stream-studio`: richer, colored C++ interface. Its Capabilities screen describes what works, what is still missing, and what distinguishes the assembly engine.

## Current capabilities and limits

It can save up to three executable paths, display and select a saved path, store simple controller profiles, and save a preferred connection strategy (LAN, direct, or relay).

It does not currently launch the selected client executable, capture or encode video/audio, send remote input, authenticate peers, or establish network/streaming connections. The remote strategy is saved as a preference only. Studio explains these limits in the application.

## Build

Install `nasm`, `g++`, `make`, and `dpkg-dev`, then run:

```sh
make
./main                 # minimal assembly interface
./cpp_ui/native_stream_gui  # Studio C++ interface
```

## Build both Debian packages and the APT repository

```sh
make deb
```

This produces `native-stream-asm_1.2.0-1_amd64.deb` and `native-stream-studio_1.2.0-1_amd64.deb`, plus the static APT repository under `dist/apt-repo`. Set another version with `VERSION=1.3.0 make deb`.

GitHub Actions rebuilds and publishes both packages and the APT metadata to GitHub Pages on each push to `main`. Enable Pages in repository settings and select **GitHub Actions** as the source. The repository landing page and apt base URL will be `https://chat10242-dev.github.io/native-stream/`.

```sh
echo 'deb [trusted=yes] https://chat10242-dev.github.io/native-stream/ stable main' | sudo tee /etc/apt/sources.list.d/native-stream.list
sudo apt update
sudo apt install native-stream-asm native-stream-studio
```

The apt metadata is unsigned and the source line therefore uses `trusted=yes`. Packages target 64-bit Debian/Ubuntu (`amd64`).

## Android assembly target

The optional ARM64/Linux assembly target is built with `make android` when `aarch64-linux-gnu` binutils are installed.

## AppImage

See [appimage/README.md](appimage/README.md) for the separate assembly-only AppImage build.
