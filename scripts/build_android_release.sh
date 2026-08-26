#!/usr/bin/env bash
# Build signed Android APK + AAB for the current VERSION.txt and selected release build number.
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
# shellcheck source=android_sdk.sh
source "$ROOT/scripts/android_sdk.sh"
ANDROID_DIR="$ROOT/mobile/android"
RELEASE_DIR="$ROOT/release"
BUILD_ROOT="$ROOT/.android-build"
VERSION_FILE="$ROOT/VERSION.txt"
BUILD_NUMBER_FILE="$ROOT/BUILD_NUMBER.txt"
BUILD_NUMBER_OVERRIDE="${BUILD_NUMBER_OVERRIDE:-}"
PERSIST_BUILD_NUMBER="${PERSIST_BUILD_NUMBER:-1}"
GRADLE_VERSION="${RANTLIST_GRADLE_VERSION:-8.9}"
KEYSTORE_PATH="${RANTLIST_ANDROID_KEYSTORE:-$HOME/.config/workwork/rantlist-android-release.keystore}"
KEY_ALIAS="${RANTLIST_ANDROID_KEY_ALIAS:-rantlist}"
KEYCHAIN_SERVICE="${RANTLIST_ANDROID_KEYCHAIN_SERVICE:-workwork.rantlist.android.keystore}"
KEYCHAIN_ACCOUNT="${RANTLIST_ANDROID_KEYCHAIN_ACCOUNT:-rantlist}"
log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || die "Android release builder currently runs from the macOS release host."
"$ROOT/scripts/check_android_release_credentials.sh" >/dev/null
# check_android_release_credentials.sh runs in a child process, so reselect and
# export the pinned JDK in this build shell before Gradle starts.
ensure_android_java
[[ -f "$VERSION_FILE" ]] || die "VERSION.txt is missing."
[[ -f "$BUILD_NUMBER_FILE" ]] || printf '0\n' > "$BUILD_NUMBER_FILE"
APP_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
[[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid VERSION.txt: $APP_VERSION"
PREVIOUS_BUILD="$(tr -cd '0-9' < "$BUILD_NUMBER_FILE")"; PREVIOUS_BUILD="${PREVIOUS_BUILD:-0}"
if [[ -n "$BUILD_NUMBER_OVERRIDE" ]]; then BUILD_NUMBER="$BUILD_NUMBER_OVERRIDE"; else BUILD_NUMBER="$((10#$PREVIOUS_BUILD + 1))"; fi
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || die "Invalid build number: $BUILD_NUMBER"
ensure_android_sdk
export ANDROID_SDK_ROOT="$SDK_ROOT" ANDROID_HOME="$SDK_ROOT"
PASSWORD="$(security find-generic-password -w -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE")"
export RANTLIST_VERSION="$APP_VERSION" RANTLIST_BUILD_NUMBER="$BUILD_NUMBER"
export RANTLIST_ANDROID_KEYSTORE="$KEYSTORE_PATH" RANTLIST_ANDROID_KEY_ALIAS="$KEY_ALIAS"
export RANTLIST_ANDROID_STORE_PASSWORD="$PASSWORD" RANTLIST_ANDROID_KEY_PASSWORD="$PASSWORD"

mkdir -p "$BUILD_ROOT/downloads" "$RELEASE_DIR"
GRADLE_HOME="$BUILD_ROOT/gradle-$GRADLE_VERSION"
if [[ ! -x "$GRADLE_HOME/bin/gradle" ]]; then
  ZIP="$BUILD_ROOT/downloads/gradle-$GRADLE_VERSION-bin.zip"
  [[ -s "$ZIP" ]] || { log "Downloading Gradle $GRADLE_VERSION"; curl --fail --location --retry 3 "https://services.gradle.org/distributions/gradle-$GRADLE_VERSION-bin.zip" -o "$ZIP"; }
  rm -rf "$GRADLE_HOME" "$BUILD_ROOT/gradle-$GRADLE_VERSION"
  unzip -q "$ZIP" -d "$BUILD_ROOT"
fi
GRADLE="$GRADLE_HOME/bin/gradle"
[[ -x "$GRADLE" ]] || die "Gradle extraction failed: $GRADLE"

log "Android build JDK: $JAVA_HOME"
"$JAVA_HOME/bin/java" -version 2>&1 | head -n 1
[[ "$(java_major "$JAVA_HOME/bin/java")" == "$ANDROID_JAVA_MAJOR" ]] || die "Android Gradle runtime must use JDK $ANDROID_JAVA_MAJOR."
log "Building signed Android APK and AAB"
"$GRADLE" --no-daemon --console=plain -p "$ANDROID_DIR" clean assembleRelease bundleRelease
APK_SRC="$ANDROID_DIR/app/build/outputs/apk/release/app-release.apk"
AAB_SRC="$ANDROID_DIR/app/build/outputs/bundle/release/app-release.aab"
[[ -s "$APK_SRC" ]] || die "Android APK was not produced."
[[ -s "$AAB_SRC" ]] || die "Android AAB was not produced."
APK="$RELEASE_DIR/Rantlist-v${APP_VERSION}-b${BUILD_NUMBER}-android.apk"
AAB="$RELEASE_DIR/Rantlist-v${APP_VERSION}-b${BUILD_NUMBER}-android.aab"
SHA="$RELEASE_DIR/Rantlist-v${APP_VERSION}-b${BUILD_NUMBER}-android-SHA256.txt"
cp "$APK_SRC" "$APK"; cp "$AAB_SRC" "$AAB"
( cd "$RELEASE_DIR"; shasum -a 256 "$(basename "$APK")" "$(basename "$AAB")" > "$(basename "$SHA")"; shasum -a 256 -c "$(basename "$SHA")" )
[[ "$PERSIST_BUILD_NUMBER" == 1 ]] && printf '%s\n' "$BUILD_NUMBER" > "$BUILD_NUMBER_FILE"
printf '\nRantlist Android release complete.\nAPK: %s\nAAB: %s\nSHA: %s\n' "$APK" "$AAB" "$SHA"
