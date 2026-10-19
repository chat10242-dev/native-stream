#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${VERSION:-1.3.0~alpha1}"
ARCH="amd64"
REPO="$ROOT/dist/apt-repo"
POOL="$REPO/pool"

for tool in nasm g++ dpkg-deb dpkg-scanpackages; do
  command -v "$tool" >/dev/null || { echo "Missing build dependency: $tool" >&2; exit 1; }
done

cd "$ROOT"
make main gui
rm -rf "$ROOT/work/native-stream-asm" "$ROOT/work/native-stream-studio"
ASM="$ROOT/work/native-stream-asm"
STUDIO="$ROOT/work/native-stream-studio"
mkdir -p "$ASM/DEBIAN" "$ASM/usr/bin" "$ASM/usr/lib/native-stream"
mkdir -p "$STUDIO/DEBIAN" "$STUDIO/usr/bin" "$POOL/main/n/native-stream-asm" "$POOL/main/n/native-stream-studio"
# Rebuild the published pool from only these two current packages.
find "$POOL" -type f -name '*.deb' -delete 2>/dev/null || true

install -m 0755 main "$ASM/usr/lib/native-stream/native_stream_asm"
ln -s ../lib/native-stream/native_stream_asm "$ASM/usr/bin/native-stream-asm"
install -m 0755 cpp_ui/native_stream_gui "$STUDIO/usr/bin/native-stream-studio"

cat > "$ASM/DEBIAN/control" <<EOF
Package: native-stream-asm
Version: ${VERSION}-1
Section: utils
Priority: optional
Architecture: ${ARCH}
Maintainer: NativeStream <native-stream@users.noreply.github.com>
Description: Minimal NativeStream terminal interface in x86_64 assembly
 NativeStream Assembly is the lightweight standalone configuration interface.
 The Studio package provides the experimental X11/H.264 UDP streaming engine.
EOF
cat > "$STUDIO/DEBIAN/control" <<EOF
Package: native-stream-studio
Version: ${VERSION}-1
Section: utils
Priority: optional
Architecture: ${ARCH}
Maintainer: NativeStream <native-stream@users.noreply.github.com>
Depends: native-stream-asm (>= ${VERSION}-1), libc6, libstdc++6, ffmpeg
Description: NativeStream Studio C++ terminal control center
 The richer C++ terminal interface offers experimental H.264 screen streaming.
 It captures X11 with FFmpeg and sends video to a reachable IPv4 client over UDP.
 Android touch input uses Linux uinput when enabled; no NAT traversal, relay,
 encryption, audio, or Android video playback is provided.
EOF

mkdir -p "$ROOT/dist"
dpkg-deb --root-owner-group --build "$ASM" "$ROOT/dist/native-stream-asm_${VERSION}-1_${ARCH}.deb"
dpkg-deb --root-owner-group --build "$STUDIO" "$ROOT/dist/native-stream-studio_${VERSION}-1_${ARCH}.deb"
install -m 0644 "$ROOT/dist/native-stream-asm_${VERSION}-1_${ARCH}.deb" "$POOL/main/n/native-stream-asm/"
install -m 0644 "$ROOT/dist/native-stream-studio_${VERSION}-1_${ARCH}.deb" "$POOL/main/n/native-stream-studio/"

mkdir -p "$REPO/dists/stable/main/binary-${ARCH}"
install -m 0644 "$ROOT/install.sh" "$REPO/install.sh"
(
  cd "$REPO"
  dpkg-scanpackages --arch "$ARCH" pool /dev/null > "dists/stable/main/binary-${ARCH}/Packages"
  gzip -9 -n -c "dists/stable/main/binary-${ARCH}/Packages" > "dists/stable/main/binary-${ARCH}/Packages.gz"
)
write_hashes() {
  local tool="$1"
  shift
  local file hash size
  for file in "$@"; do
    hash="$("$tool" "$file" | awk '{print $1}')"
    size="$(wc -c < "$file" | tr -d ' ')"
    printf ' %s %s %s\n' "$hash" "$size" "$file"
  done
}

(
cd "$REPO/dists/stable"
PACKAGE_FILES=("main/binary-${ARCH}/Packages" "main/binary-${ARCH}/Packages.gz")
cat > "Release" <<EOF
Origin: NativeStream
Label: NativeStream
Suite: stable
Codename: stable
Date: $(date -Ru)
Architectures: ${ARCH}
Components: main
Description: NativeStream APT repository
MD5Sum:
$(write_hashes md5sum "${PACKAGE_FILES[@]}")
SHA1:
$(write_hashes sha1sum "${PACKAGE_FILES[@]}")
SHA256:
$(write_hashes sha256sum "${PACKAGE_FILES[@]}")
EOF
)
cat > "$REPO/index.html" <<'EOF'
<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>NativeStream APT</title>
<style>body{font:16px system-ui,sans-serif;max-width:760px;margin:3rem auto;padding:0 1rem;color:#172033}code,pre{background:#eef2f7;padding:.25rem .4rem;border-radius:.3rem}pre{padding:1rem;overflow:auto}.tag{color:#087f5b}</style>
<h1>NativeStream APT repository</h1>
<p>Minimal Assembly and richer C++ terminal interfaces. Studio has experimental H.264 screen streaming.</p>
<ul><li><code>native-stream-asm</code> — minimal assembly interface.</li><li><code>native-stream-studio</code> — richer C++ interface with capabilities and limitations.</li></ul>
<p class="tag">Studio includes experimental X11/H.264 video and Android touch input over UDP. Host must be reachable by IPv4; NAT traversal, relay, encryption, audio, and Android video playback are not implemented.</p>
<h2>Install on Debian or Ubuntu (amd64)</h2>
<pre>curl -fsSL https://chat10242-dev.github.io/native-stream/install.sh | sudo bash</pre>
<p>The APT metadata is currently unsigned. Review and run the installer only if you trust this project.</p>
<p>Direct packages: <a href="pool/main/n/native-stream-asm/native-stream-asm_${VERSION}-1_amd64.deb">assembly</a> · <a href="pool/main/n/native-stream-studio/native-stream-studio_${VERSION}-1_amd64.deb">studio</a></p>
</html>
EOF
printf 'Packages created in %s\n' "$ROOT/dist"
