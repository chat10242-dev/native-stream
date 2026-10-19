# NativeStream

NativeStream is an early prototype for Debian/Ubuntu amd64 with two terminal interfaces:

- `native-stream-asm`: minimal standalone configuration menu written in assembly.
- `native-stream-studio`: richer, colored C++ interface and experimental video-streaming engine.

## Current capabilities and limits

The Studio package includes an experimental one-way screen video stream: FFmpeg captures an X11 display, encodes H.264, and sends it over UDP to a client which decodes it with FFmpeg. The host and client use a shared PIN for a basic handshake.

This is an early prototype, not a complete remote desktop. It requires an X11 host, FFmpeg with libx264 and ffplay, IPv4 reachability to the host, and a UDP path that does not block the selected port. It has no NAT traversal/rendezvous/relay, encryption, audio, remote input, congestion control, or robust recovery from packet loss. It will not connect arbitrary networks behind restrictive NATs without an external VPN, port mapping, or future relay service. Studio explains these limits in the application.

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

This produces `native-stream-asm_1.3.0~alpha1-1_amd64.deb` and `native-stream-studio_1.3.0~alpha1-1_amd64.deb`, plus the static APT repository under `dist/apt-repo`. Set another version with `VERSION=1.3.0~alpha2 make deb`.

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
