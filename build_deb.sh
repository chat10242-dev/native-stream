#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${VERSION:-1.1.0}"
ARCH="amd64"
PKG="native-stream"
WORK="$ROOT/work/$PKG"
POOL="$ROOT/dist/apt-repo/pool/main/n/native-stream"
REPO="$ROOT/dist/apt-repo"

command -v nasm >/dev/null || { echo "Missing build dependency: nasm" >&2; exit 1; }
command -v g++ >/dev/null || { echo "Missing build dependency: g++" >&2; exit 1; }
command -v dpkg-deb >/dev/null || { echo "Missing build dependency: dpkg-deb" >&2; exit 1; }

cd "$ROOT"
make main gui
rm -rf "$WORK"
mkdir -p "$WORK/DEBIAN" "$WORK/usr/bin" "$WORK/usr/lib/native-stream" "$POOL"
# Keep the published index focused on the current single-package distribution.
find "$REPO/pool" -type f -name '*.deb' -delete 2>/dev/null || true
install -m 0755 cpp_ui/native_stream_gui "$WORK/usr/bin/native-stream"
install -m 0755 main "$WORK/usr/lib/native-stream/native_stream_asm"
cat > "$WORK/DEBIAN/control" <<EOF
Package: native-stream
Version: ${VERSION}-1
Section: utils
Priority: optional
Architecture: ${ARCH}
Maintainer: NativeStream <native-stream@users.noreply.github.com>
Depends: libc6, libstdc++6
Description: NativeStream terminal interface with an assembly engine
 NativeStream uses a C++ terminal menu and a native x86_64 assembly engine.
EOF

mkdir -p "$ROOT/dist"
dpkg-deb --root-owner-group --build "$WORK" "$ROOT/dist/${PKG}_${VERSION}-1_${ARCH}.deb"
install -m 0644 "$ROOT/dist/${PKG}_${VERSION}-1_${ARCH}.deb" "$POOL/"

mkdir -p "$REPO/dists/stable/main/binary-${ARCH}"
(
  cd "$REPO"
  dpkg-scanpackages --arch "$ARCH" pool /dev/null > "dists/stable/main/binary-${ARCH}/Packages"
  gzip -9 -n -c "dists/stable/main/binary-${ARCH}/Packages" > "dists/stable/main/binary-${ARCH}/Packages.gz"
)
cat > "$REPO/dists/stable/Release" <<EOF
Origin: NativeStream
Label: NativeStream
Suite: stable
Codename: stable
Architectures: ${ARCH}
Components: main
Description: NativeStream APT repository
EOF
printf 'Package built: %s\n' "$ROOT/dist/${PKG}_${VERSION}-1_${ARCH}.deb"
printf 'APT repository: %s\n' "$REPO"
