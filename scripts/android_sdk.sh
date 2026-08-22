#!/usr/bin/env bash
# Shared Android SDK discovery/provisioning helpers for the Rantlist release host.
set -Eeuo pipefail

ANDROID_API_LEVEL="${RANTLIST_ANDROID_API_LEVEL:-35}"
ANDROID_BUILD_TOOLS_VERSION="${RANTLIST_ANDROID_BUILD_TOOLS_VERSION:-35.0.0}"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"

android_sdk_die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
android_sdk_log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }

java_major(){
  local java_bin="$1"
  "$java_bin" -version 2>&1 | awk -F'[".]' '/version/ { if ($2 == "1") print $3; else print $2; exit }'
}

ensure_android_java(){
  local home="" major=""
  if [[ -x /usr/libexec/java_home ]]; then
    home="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
    if [[ -n "$home" && -x "$home/bin/java" ]]; then
      export JAVA_HOME="$home"
      export PATH="$JAVA_HOME/bin:$PATH"
      return 0
    fi
  fi
  for home in \
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
    /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
    /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home; do
    if [[ -x "$home/bin/java" ]]; then
      major="$(java_major "$home/bin/java")"
      if [[ "$major" =~ ^[0-9]+$ && "$major" -ge 17 ]]; then
        export JAVA_HOME="$home"
        export PATH="$JAVA_HOME/bin:$PATH"
        return 0
      fi
    fi
  done
  if command -v java >/dev/null 2>&1; then
    major="$(java_major "$(command -v java)")"
    if [[ "$major" =~ ^[0-9]+$ && "$major" -ge 17 && "$major" -le 23 ]]; then
      return 0
    fi
  fi
  if command -v brew >/dev/null 2>&1 && [[ "${RANTLIST_ANDROID_AUTO_INSTALL_TOOLS:-1}" == 1 ]]; then
    android_sdk_log "Installing OpenJDK 17 for Android builds"
    brew list --versions openjdk@17 >/dev/null 2>&1 || brew install openjdk@17
    for home in \
      /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
      /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home; do
      if [[ -x "$home/bin/java" ]]; then
        export JAVA_HOME="$home"
        export PATH="$JAVA_HOME/bin:$PATH"
        return 0
      fi
    done
  fi
  android_sdk_die "A Java 17+ runtime suitable for Android builds was not found. Install Android Studio or Homebrew openjdk@17."
}

find_sdkmanager(){
  local candidate=""
  if command -v sdkmanager >/dev/null 2>&1; then
    command -v sdkmanager
    return 0
  fi
  for candidate in \
    "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" \
    "$SDK_ROOT/cmdline-tools/bin/sdkmanager" \
    "$SDK_ROOT/tools/bin/sdkmanager" \
    /opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager \
    /usr/local/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager \
    "/Applications/Android Studio.app/Contents/cmdline-tools/latest/bin/sdkmanager"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  # Android Studio permits multiple versioned cmdline-tools folders.
  if [[ -d "$SDK_ROOT/cmdline-tools" ]]; then
    candidate="$(find "$SDK_ROOT/cmdline-tools" -maxdepth 3 -type f -name sdkmanager -perm -111 2>/dev/null | sort -Vr | head -n 1 || true)"
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi
  return 1
}

android_sdk_ready(){
  [[ -f "$SDK_ROOT/platforms/android-${ANDROID_API_LEVEL}/android.jar" ]] && \
  [[ -x "$SDK_ROOT/build-tools/${ANDROID_BUILD_TOOLS_VERSION}/aapt2" ]]
}

ensure_android_sdk(){
  export ANDROID_SDK_ROOT="$SDK_ROOT" ANDROID_HOME="$SDK_ROOT"
  if android_sdk_ready; then
    return 0
  fi

  ensure_android_java
  local sdkmanager_bin=""
  sdkmanager_bin="$(find_sdkmanager || true)"
  if [[ -z "$sdkmanager_bin" && "${RANTLIST_ANDROID_AUTO_INSTALL_TOOLS:-1}" == 1 ]] && command -v brew >/dev/null 2>&1; then
    android_sdk_log "Installing Android command-line tools"
    brew list --cask android-commandlinetools >/dev/null 2>&1 || brew install --cask android-commandlinetools
    sdkmanager_bin="$(find_sdkmanager || true)"
  fi
  if [[ -z "$sdkmanager_bin" ]]; then
    android_sdk_die "Android SDK API ${ANDROID_API_LEVEL} is incomplete under $SDK_ROOT and sdkmanager was not found. Install Android Studio Command-line Tools once; the Rantlist release script will install the required SDK packages after that."
  fi

  mkdir -p "$SDK_ROOT"
  android_sdk_log "Installing required Android SDK packages (API ${ANDROID_API_LEVEL})"
  if ! "$sdkmanager_bin" --sdk_root="$SDK_ROOT" \
      "platforms;android-${ANDROID_API_LEVEL}" \
      "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
      "platform-tools"; then
    android_sdk_die "Android SDK package installation failed. If Android SDK licenses have not yet been accepted on this Mac, run: $sdkmanager_bin --sdk_root='$SDK_ROOT' --licenses"
  fi

  [[ -f "$SDK_ROOT/platforms/android-${ANDROID_API_LEVEL}/android.jar" ]] || \
    android_sdk_die "Android SDK platform ${ANDROID_API_LEVEL} is still missing after sdkmanager completed."
  [[ -x "$SDK_ROOT/build-tools/${ANDROID_BUILD_TOOLS_VERSION}/aapt2" ]] || \
    android_sdk_die "Android Build Tools ${ANDROID_BUILD_TOOLS_VERSION} are still missing after sdkmanager completed."
}
