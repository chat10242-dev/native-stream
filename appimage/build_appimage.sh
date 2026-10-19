#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$ROOT/.." && pwd)"
APPDIR="$ROOT/AppDir"
OUT="${1:-$PROJECT_ROOT/NativeStream-x86_64.AppImage}"
APPIMAGETOOL_BIN="${APPIMAGETOOL_BIN:-}"

if [ ! -x "$PROJECT_ROOT/main" ]; then
  echo "Building native binary..."
  make -C "$PROJECT_ROOT" >/dev/null
fi

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/scalable/apps"

if [ ! -f "$ROOT/NativeStream.png" ]; then
  python3 - "$ROOT/NativeStream.png" <<'PY'
from PIL import Image, ImageDraw
import sys
path = sys.argv[1]
img = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle((20, 20, 492, 492), radius=70, fill=(15, 23, 42, 255))
d.rounded_rectangle((40, 40, 472, 472), radius=50, outline=(90, 180, 255, 255), width=10, fill=(18, 30, 54, 255))
d.rounded_rectangle((110, 150, 402, 362), radius=28, fill=(28, 41, 68, 255))
d.text((138, 178), ">", fill=(255, 255, 255, 255))
d.text((138, 210), 'Native', fill=(130, 200, 255, 255))
d.text((138, 250), 'Stream', fill=(130, 200, 255, 255))
for x in [146, 246, 346]:
    d.rounded_rectangle((x, 280, x + 68, 314), radius=12, fill=(82, 196, 255, 255))
points = [(360, 150), (420, 210), (360, 270)]
d.polygon(points, fill=(90, 220, 160, 255))
img.save(path)
PY
fi

cp "$PROJECT_ROOT/main" "$APPDIR/usr/bin/native_stream"
chmod 755 "$APPDIR/usr/bin/native_stream"
install -m 755 "$ROOT/AppRun" "$APPDIR/AppRun"
cp "$ROOT/NativeStream.desktop" "$APPDIR/NativeStream.desktop"
cp "$ROOT/NativeStream.desktop" "$APPDIR/usr/share/applications/NativeStream.desktop"
cp "$ROOT/NativeStream.svg" "$APPDIR/native_stream.svg"
cp "$ROOT/NativeStream.svg" "$APPDIR/usr/share/icons/hicolor/scalable/apps/native_stream.svg"
cp "$ROOT/NativeStream.png" "$APPDIR/native_stream.png"
cp "$ROOT/NativeStream.png" "$APPDIR/usr/share/icons/hicolor/scalable/apps/native_stream.png"

# Compatibility for AppImageKit and desktop-entry lookups.
cp "$ROOT/NativeStream.svg" "$APPDIR/.DirIcon"

if [ -z "$APPIMAGETOOL_BIN" ]; then
  if command -v appimagetool >/dev/null 2>&1; then
    APPIMAGETOOL_BIN="$(command -v appimagetool)"
  else
    APPIMAGETOOL_BIN="$HOME/.local/bin/appimagetool"
    mkdir -p "$(dirname "$APPIMAGETOOL_BIN")"
    if [ ! -x "$APPIMAGETOOL_BIN" ]; then
      echo "Downloading AppImageTool..."
      if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$APPIMAGETOOL_BIN" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
      elif command -v wget >/dev/null 2>&1; then
        wget -qO "$APPIMAGETOOL_BIN" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
      else
        echo "curl or wget is required to fetch appimagetool." >&2
        exit 1
      fi
      chmod +x "$APPIMAGETOOL_BIN"
    fi
  fi
fi

if [ ! -x "$APPIMAGETOOL_BIN" ]; then
  echo "appimagetool is missing. Install it and retry." >&2
  exit 1
fi

"$APPIMAGETOOL_BIN" "$APPDIR" "$OUT"
echo "AppImage created: $OUT"
