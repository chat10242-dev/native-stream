#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Esegui questo comando con sudo." >&2
    exit 1
fi
if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    echo "NativeStream al momento supporta solo Debian/Ubuntu amd64." >&2
    exit 1
fi
if ! command -v apt-get >/dev/null 2>&1; then
    echo "Serve una distribuzione Debian o Ubuntu con apt." >&2
    exit 1
fi

echo 'deb [trusted=yes] https://chat10242-dev.github.io/native-stream/ stable main' \
    > /etc/apt/sources.list.d/native-stream.list
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y native-stream-asm native-stream-studio
