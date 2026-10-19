#!/bin/bash
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$ROOT/.." && pwd)"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}"
GRADLE_HOME="${GRADLE_HOME:-$HOME/.local/share/gradle}"
GRADLE_VERSION="8.7"

ensure_java() {
  if command -v java >/dev/null 2>&1; then
    return 0
  fi

  for candidate in \
    "${JAVA_HOME:-}" \
    "/usr/lib/jvm/default-java" \
    "/usr/lib/jvm/java-21-openjdk-amd64" \
    "/usr/lib/jvm/java-21-openjdk" \
    "/usr/lib/jvm/java-17-openjdk-amd64" \
    "/usr/lib/jvm/java-17-openjdk" \
    "/usr/lib/jvm/java-11-openjdk-amd64"; do
    if [ -n "$candidate" ] && [ -x "$candidate/bin/java" ]; then
      export JAVA_HOME="$candidate"
      export PATH="$JAVA_HOME/bin:$PATH"
      return 0
    fi
  done

  if command -v apt-get >/dev/null 2>&1; then
    echo "Java not found. Installing JDK..."
    if command -v sudo >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y openjdk-21-jdk wget unzip
    else
      apt-get update
      apt-get install -y openjdk-21-jdk wget unzip
    fi
    if command -v java >/dev/null 2>&1; then
      return 0
    fi
  fi

  echo "Java is required for Android APK builds. Install JDK with:"
  echo "  sudo apt update"
  echo "  sudo apt install -y openjdk-21-jdk wget unzip"
  return 1
}

ensure_sdkmanager() {
  if command -v sdkmanager >/dev/null 2>&1; then
    return 0
  fi

  local sdk_candidates=(
    "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
    "$ANDROID_SDK_ROOT/cmdline-tools/bin/sdkmanager"
    "$ANDROID_SDK_ROOT/tools/bin/sdkmanager"
    "$ANDROID_SDK_ROOT/platform-tools/sdkmanager"
  )

  for candidate in "${sdk_candidates[@]}"; do
    if [ -x "$candidate" ]; then
      export PATH="$(dirname "$candidate"):$PATH"
      return 0
    fi
  done

  return 1
}

if ! ensure_java; then
  exit 1
fi

if ! ensure_sdkmanager; then
  echo "Android SDK not found. Installing command-line tools to $ANDROID_SDK_ROOT"
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
  CMDTOOLS_ZIP="${TMPDIR:-/tmp}/cmdline-tools.zip"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$CMDTOOLS_ZIP" "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$CMDTOOLS_ZIP" "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
  else
    echo "curl or wget is required to download the Android command-line tools." >&2
    exit 1
  fi

  unzip -q -o "$CMDTOOLS_ZIP" -d "$ANDROID_SDK_ROOT/cmdline-tools"
  if [ -d "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" ]; then
    rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/latest"
    mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  fi

  export ANDROID_SDK_ROOT
  export ANDROID_HOME
  if [ -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
    export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
    yes | "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
    "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" "platform-tools" "platforms;android-34" "build-tools;34.0.0"
  else
    echo "SDK installation failed: sdkmanager not found in $ANDROID_SDK_ROOT" >&2
    exit 1
  fi
fi

if ! command -v gradle >/dev/null 2>&1 || [ "$(gradle -v 2>/dev/null | sed -n 's/^Gradle //p' | head -n 1 | cut -d. -f1 || echo 0)" -lt 8 ]; then
  echo "Installing a compatible Gradle $GRADLE_VERSION..."
  mkdir -p "$GRADLE_HOME"
  GRADLE_DIST="$GRADLE_HOME/gradle-${GRADLE_VERSION}-bin.zip"
  if [ ! -f "$GRADLE_DIST" ]; then
    curl -fsSL -o "$GRADLE_DIST" "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip"
  fi
  unzip -q -o "$GRADLE_DIST" -d "$GRADLE_HOME"
  export PATH="$GRADLE_HOME/gradle-${GRADLE_VERSION}/bin:$PATH"
  export GRADLE_HOME
fi

if [ ! -f "$ROOT/gradlew" ]; then
  cd "$ROOT"
  gradle wrapper --gradle-version "$GRADLE_VERSION" --distribution-type bin
fi

printf 'sdk.dir=%s\n' "$ANDROID_SDK_ROOT" > "$ROOT/local.properties"
export ANDROID_SDK_ROOT
export ANDROID_HOME
cd "$ROOT"
./gradlew assembleDebug
