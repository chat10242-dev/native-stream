# NativeStream

NativeStream is a Linux terminal program with a C++ menu and a NASM x86_64 assembly engine. The menu keeps the same plain text panel as the original assembly interface; the host, client, profile, and remote setup operations run in assembly.

## Build and run from source

Install `nasm`, `g++`, `make`, and `dpkg-dev`, then run:

```sh
make
./cpp_ui/native_stream_gui
```

The launcher locates the assembly engine in the source tree or at `/usr/lib/native-stream/native_stream_asm` when installed.

## Debian package and APT repository

Build the unified `amd64` package and its repository index with:

```sh
make deb
```

This creates `dist/native-stream_1.1.0-1_amd64.deb` and the static APT repository under `dist/apt-repo`. You can set another version with `VERSION=1.2.0 make deb`.

GitHub Actions rebuilds the package and publishes the APT repository to GitHub Pages on every push to `main`. In the repository settings, enable Pages and select **GitHub Actions** as the source. The repository address will be:

```text
https://chat10242-dev.github.io/native-stream/
```

After Pages finishes its first deployment, install with:

```sh
echo 'deb [trusted=yes] https://chat10242-dev.github.io/native-stream/ stable main' | sudo tee /etc/apt/sources.list.d/native-stream.list
sudo apt update
sudo apt install native-stream
```

The package installs `/usr/bin/native-stream` and `/usr/lib/native-stream/native_stream_asm`. The APT repository is unsigned; the source line uses `trusted=yes`.

## Android assembly target

The optional ARM64/Linux assembly target is built with `make android` when the `aarch64-linux-gnu` binutils are installed.

## AppImage

See [appimage/README.md](appimage/README.md) for the separate assembly-only AppImage build.
