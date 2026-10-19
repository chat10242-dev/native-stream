# NativeStream

NativeStream is an early prototype for Debian/Ubuntu amd64 with two terminal interfaces:

- `native-stream-asm`: minimal standalone configuration menu written in assembly.
- `native-stream-studio`: richer, colored C++ interface and experimental video-streaming engine.

## Current capabilities and limits

The Studio package includes an experimental one-way screen video stream: FFmpeg captures an X11 display, encodes H.264, and sends it over UDP to a client which decodes it with FFmpeg. The host and client use a shared PIN for a basic handshake.

This is an early prototype, not a complete remote desktop. It requires an X11 host, FFmpeg with libx264 and ffplay, `/dev/uinput` access for remote controls, IPv4 reachability to the host, and UDP ports `47999` and `48000` (or the selected port and the next port) allowed through the firewall. It has no NAT traversal/rendezvous/relay, encryption, audio, Android video playback, congestion control, or robust recovery from packet loss. It will not connect arbitrary networks behind restrictive NATs without an external VPN, port mapping, or future relay service. Studio explains these limits in the application.

The Android app now lets you create a separate touch layout for each game, move its buttons, and change each button's keyboard/mouse binding. The crosshair Mira button holds right mouse; the Fuoco button holds left mouse. Dragging on any uncovered part of the layout sends relative mouse movement. The Linux host injects those events through `/dev/uinput`; the user needs access to that device. The Android screen is currently a control-layout prototype without video playback, and input packets are not encrypted. Use only on a trusted network or VPN.

To enable the Linux virtual input device, load the kernel module and grant the intended account access to `/dev/uinput` (then sign out and back in):

```sh
sudo modprobe uinput
echo 'KERNEL=="uinput", GROUP="input", MODE="0660"' | sudo tee /etc/udev/rules.d/99-native-stream-uinput.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usermod -aG input "$USER"
```

Only do this on a machine where you trust the remote-control client: this prototype sends unencrypted key and mouse events.

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
