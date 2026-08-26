#!/usr/bin/env bash
# Shared Android SDK discovery/provisioning helpers for the Rantlist release host.
set -Eeuo pipefail

ANDROID_API_LEVEL="${RANTLIST_ANDROID_API_LEVEL:-35}"
ANDROID_BUILD_TOOLS_VERSION="${RANTLIST_ANDROID_BUILD_TOOLS_VERSION:-35.0.0}"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ANDROID_JAVA_MAJOR="${RANTLIST_ANDROID_JAVA_MAJOR:-17}"

android_sdk_die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
android_sdk_log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }

java_major(){
  local java_bin="$1"
  "$java_bin" -version 2>&1 | awk -F'[".]' '/version/ { if ($2 == "1") print $3; else print $2; exit }'
}

use_android_java_home(){
  local home="$1" major=""
  [[ -n "$home" && -x "$home/bin/java" ]] || return 1
  major="$(java_major "$home/bin/java")"
  [[ "$major" == "$ANDROID_JAVA_MAJOR" ]] || return 1
  export JAVA_HOME="$home"
  export PATH="$JAVA_HOME/bin:$PATH"
  return 0
}

ensure_android_java(){
  local home=""

  # Explicit override wins, but must be the pinned Android JDK major.
  if [[ -n "${RANTLIST_ANDROID_JAVA_HOME:-}" ]]; then
    use_android_java_home "$RANTLIST_ANDROID_JAVA_HOME" || \
      android_sdk_die "RANTLIST_ANDROID_JAVA_HOME must point to JDK ${ANDROID_JAVA_MAJOR}."
    return 0
  fi

  # Prefer the Homebrew JDK 17 keg directly. It does not need to be made the
  # system-wide default or linked into /Library/Java/JavaVirtualMachines.
  for home in \
    /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
    /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home; do
    if use_android_java_home "$home"; then
      return 0
    fi
  done

  # Then accept a correctly registered macOS JDK 17.
  if [[ -x /usr/libexec/java_home ]]; then
    home="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
    if use_android_java_home "$home"; then
      return 0
    fi
  fi

  # Android Studio may carry JDK 17 on some installations.
  if use_android_java_home "/Applications/Android Studio.app/Contents/jbr/Contents/Home"; then
    return 0
  fi

  if command -v brew >/dev/null 2>&1 && [[ "${RANTLIST_ANDROID_AUTO_INSTALL_TOOLS:-1}" == 1 ]]; then
    android_sdk_log "Installing OpenJDK ${ANDROID_JAVA_MAJOR} for Android builds"
    brew list --versions openjdk@17 >/dev/null 2>&1 || brew install openjdk@17
    for home in \
      /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
      /usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home; do
      if use_android_java_home "$home"; then
        return 0
      fi
    done
  fi

  android_sdk_die "JDK ${ANDROID_JAVA_MAJOR} was not found. Install Homebrew openjdk@17 or set RANTLIST_ANDROID_JAVA_HOME to a JDK ${ANDROID_JAVA_MAJOR} home."
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
