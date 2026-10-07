#!/usr/bin/env bash
# Build the separate signed Meta Quest PWA using the published Meta Quest Bubblewrap CLI.
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
# shellcheck source=android_sdk.sh
source "$ROOT/scripts/android_sdk.sh"
RELEASE_DIR="$ROOT/release"
QUEST_SOURCE="$ROOT/mobile/quest"
QUEST_BUILD="$ROOT/.quest-bubblewrap-build/project"
VERSION_FILE="$ROOT/VERSION.txt"
BUILD_NUMBER_FILE="$ROOT/BUILD_NUMBER.txt"
BUILD_NUMBER_OVERRIDE="${BUILD_NUMBER_OVERRIDE:-}"
PERSIST_BUILD_NUMBER="${PERSIST_BUILD_NUMBER:-1}"
INSTALL_CONNECTED="${RANTLIST_QUEST_INSTALL_CONNECTED:-1}"
KEYSTORE_PATH="${RANTLIST_ANDROID_KEYSTORE:-$HOME/.config/workwork/rantlist-android-release.keystore}"
KEY_ALIAS="${RANTLIST_ANDROID_KEY_ALIAS:-rantlist}"
KEYCHAIN_SERVICE="${RANTLIST_ANDROID_KEYCHAIN_SERVICE:-workwork.rantlist.android.keystore}"
KEYCHAIN_ACCOUNT="${RANTLIST_ANDROID_KEYCHAIN_ACCOUNT:-rantlist}"
BUBBLEWRAP_VERSION="${RANTLIST_QUEST_BUBBLEWRAP_VERSION:-1.24.1}"
log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
install_connected_quest_devices() {
  [[ "$INSTALL_CONNECTED" == "1" ]] || { log "Connected Quest install disabled (RANTLIST_QUEST_INSTALL_CONNECTED=$INSTALL_CONNECTED)"; return 0; }

  local adb_bin=""
  if [[ -x "$SDK_ROOT/platform-tools/adb" ]]; then
    adb_bin="$SDK_ROOT/platform-tools/adb"
  elif command -v adb >/dev/null 2>&1; then
    adb_bin="$(command -v adb)"
  else
    printf '\033[1;31mERROR:\033[0m adb is unavailable; Quest APK was built but not installed.\n' >&2
    return 0
  fi

  local found=0 seen_usb=0 unauthorized=0 line serial state manufacturer model brand identity
  while IFS= read -r line; do
    [[ -n "$line" && "$line" != "List of devices attached" && "$line" != \** ]] || continue
    serial="$(awk '{print $1}' <<<"$line")"
    state="$(awk '{print $2}' <<<"$line")"
    [[ -n "$serial" && -n "$state" ]] || continue
    seen_usb=1
    if [[ "$state" == "unauthorized" ]]; then
      unauthorized=1
      printf '\033[1;31mERROR:\033[0m ADB device %s is connected but USB debugging is not authorised. Approve the prompt inside Quest.\n' "$serial" >&2
      continue
    fi
    [[ "$state" == "device" ]] || continue
    manufacturer="$($adb_bin -s "$serial" shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\r')"
    model="$($adb_bin -s "$serial" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
    brand="$($adb_bin -s "$serial" shell getprop ro.product.brand 2>/dev/null | tr -d '\r')"
    identity="${manufacturer} ${model} ${brand} ${line}"
    if ! printf '%s' "$identity" | grep -Eiq '(meta|oculus|quest)'; then continue; fi
    found=1
    log "Installing Rantlist $APP_VERSION build $BUILD_NUMBER on connected Quest: ${model:-$serial} ($serial)"
    if "$adb_bin" -s "$serial" install -r "$APK"; then
      log "Installed Rantlist on ${model:-Quest}"
      "$adb_bin" -s "$serial" shell am force-stop fun.workwork.rantlist >/dev/null 2>&1 || true
      if "$adb_bin" -s "$serial" shell monkey -p fun.workwork.rantlist -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; then
        log "Launched Rantlist on ${model:-Quest}"
      else
        printf '\033[1;31mERROR:\033[0m Rantlist installed on %s but could not be launched automatically.\n' "${model:-Quest}" >&2
      fi
    else
      printf '\033[1;31mERROR:\033[0m Could not install Rantlist on %s.\n' "${model:-Quest}" >&2
    fi
  done < <("$adb_bin" devices -l)

  if [[ "$found" == 0 ]]; then
    if [[ "$unauthorized" == 1 ]]; then
      printf '\033[1;31mERROR:\033[0m Quest APK was built but not installed because ADB is not authorised.\n' >&2
    elif [[ "$seen_usb" == 1 ]]; then
      printf '\033[1;31mERROR:\033[0m ADB sees a USB device, but it was not identified as Meta/Oculus/Quest.\n' >&2
    else
      printf '\033[1;31mERROR:\033[0m No ADB device is visible; Quest APK was built but not installed.\n' >&2
    fi
  fi
}
[[ "$(uname -s)" == Darwin ]] || die "Quest release builder currently runs from the macOS release host."
"$ROOT/scripts/check_android_release_credentials.sh" >/dev/null
ensure_android_java
ensure_android_sdk

# Bubblewrap keeps its JDK/SDK paths in ~/.bubblewrap/config.json and otherwise
# prompts on first use. Meta Bubblewrap 1.24.1 validates its own SDK layout more
# narrowly than Android Studio's normal SDK root, so expose the verified Rantlist
# SDK through an isolated Bubblewrap-compatible view.
BUBBLEWRAP_CONFIG_DIR="$HOME/.bubblewrap"
BUBBLEWRAP_CONFIG="$BUBBLEWRAP_CONFIG_DIR/config.json"
BUBBLEWRAP_SDK="$ROOT/.quest-bubblewrap-build/android-sdk"
JDK_BUNDLE="${JAVA_HOME%/Contents/Home}"
[[ -f "$JDK_BUNDLE/Contents/Home/release" ]] || die "Bubblewrap JDK bundle root is invalid: $JDK_BUNDLE"
SDKMANAGER_BIN="$(find_sdkmanager || true)"
[[ -n "$SDKMANAGER_BIN" ]] || die "Android sdkmanager is required for Meta Quest Bubblewrap."
SDKMANAGER_DIR="$(dirname "$SDKMANAGER_BIN")"
command -v node >/dev/null || die "Node.js is required for Meta Quest Bubblewrap."
mkdir -p "$BUBBLEWRAP_SDK" "$BUBBLEWRAP_CONFIG_DIR"
ln -sfn "$SDKMANAGER_DIR" "$BUBBLEWRAP_SDK/bin"
for sdk_part in build-tools platform-tools platforms licenses; do
  if [[ -e "$SDK_ROOT/$sdk_part" ]]; then
    ln -sfn "$SDK_ROOT/$sdk_part" "$BUBBLEWRAP_SDK/$sdk_part"
  fi
done

# Gradle fails closed if two SDK variables point at different locations. Bubblewrap
# and Gradle therefore receive exactly the same synthetic SDK root.
unset ANDROID_SDK_ROOT
export ANDROID_HOME="$BUBBLEWRAP_SDK"
node - "$BUBBLEWRAP_CONFIG" "$JDK_BUNDLE" "$BUBBLEWRAP_SDK" <<'NODE'
const fs = require('fs');
const [configPath, jdkPath, androidSdkPath] = process.argv.slice(2);
fs.writeFileSync(configPath, JSON.stringify({jdkPath, androidSdkPath}) + '\n', {mode: 0o600});
NODE

command -v node >/dev/null || die "Node.js is required for Meta Quest Bubblewrap."
command -v npm >/dev/null || die "npm is required for Meta Quest Bubblewrap."
NODE_MAJOR="$(node -p 'Number(process.versions.node.split(`.`)[0])')"
(( NODE_MAJOR >= 18 )) || die "Meta Quest Bubblewrap requires Node.js 18 or later."
[[ -f "$VERSION_FILE" ]] || die "VERSION.txt is missing."
[[ -f "$BUILD_NUMBER_FILE" ]] || printf '0\n' > "$BUILD_NUMBER_FILE"
APP_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
[[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid VERSION.txt: $APP_VERSION"
PREVIOUS_BUILD="$(tr -cd '0-9' < "$BUILD_NUMBER_FILE")"; PREVIOUS_BUILD="${PREVIOUS_BUILD:-0}"
if [[ -n "$BUILD_NUMBER_OVERRIDE" ]]; then BUILD_NUMBER="$BUILD_NUMBER_OVERRIDE"; else BUILD_NUMBER="$((10#$PREVIOUS_BUILD + 1))"; fi
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || die "Invalid build number: $BUILD_NUMBER"
[[ -f "$KEYSTORE_PATH" ]] || die "Android release keystore not found: $KEYSTORE_PATH"
PASSWORD="$(security find-generic-password -w -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE")"
[[ -n "$PASSWORD" ]] || die "Android release keystore password is unavailable."
log "Checking hosted Rantlist PWA manifest"
curl --fail --silent --show-error --location --max-time 20 https://rantlist.me/manifest.webmanifest \
  | grep -q '"name"[[:space:]]*:[[:space:]]*"Rantlist"' \
  || die "https://rantlist.me/manifest.webmanifest is not deployed yet. Deploy server r538 first."
rm -rf "$QUEST_BUILD"
mkdir -p "$QUEST_BUILD" "$RELEASE_DIR"
node "$ROOT/scripts/write_quest_twa_manifest.js" \
  --template "$QUEST_SOURCE/twa-manifest.template.json" \
  --output "$QUEST_BUILD/twa-manifest.json" \
  --version "$APP_VERSION" \
  --build "$BUILD_NUMBER" \
  --keystore "$KEYSTORE_PATH" \
  --alias "$KEY_ALIAS"
BUBBLEWRAP=(npx --yes --package "@meta-quest/bubblewrap-cli@${BUBBLEWRAP_VERSION}" bubblewrap)
log "Meta Quest Bubblewrap CLI ${BUBBLEWRAP_VERSION}"
"${BUBBLEWRAP[@]}" --version
log "Validating Bubblewrap JDK and Android SDK"
"${BUBBLEWRAP[@]}" doctor
log "Generating Quest Android project from the hosted PWA manifest"
(
  cd "$QUEST_BUILD"
  "${BUBBLEWRAP[@]}" update --skipVersionUpgrade
)
log "Building signed Meta Quest Bubblewrap APK and AAB"
(
  cd "$QUEST_BUILD"
  BUBBLEWRAP_KEYSTORE_PASSWORD="$PASSWORD" \
  BUBBLEWRAP_KEY_PASSWORD="$PASSWORD" \
  "${BUBBLEWRAP[@]}" build \
    --signingKeyPath="$KEYSTORE_PATH" \
    --signingKeyAlias="$KEY_ALIAS"
)
APK_SRC="$QUEST_BUILD/app-release-signed.apk"
AAB_SRC="$QUEST_BUILD/app-release-bundle.aab"
[[ -s "$APK_SRC" ]] || die "Bubblewrap APK was not produced: $APK_SRC"
[[ -s "$AAB_SRC" ]] || die "Bubblewrap AAB was not produced: $AAB_SRC"
APK="$RELEASE_DIR/Rantlist-v${APP_VERSION}-b${BUILD_NUMBER}-quest.apk"
AAB="$RELEASE_DIR/Rantlist-v${APP_VERSION}-b${BUILD_NUMBER}-quest.aab"
SHA="$RELEASE_DIR/Rantlist-v${APP_VERSION}-b${BUILD_NUMBER}-quest-SHA256.txt"
cp "$APK_SRC" "$APK"; cp "$AAB_SRC" "$AAB"
( cd "$RELEASE_DIR"; shasum -a 256 "$(basename "$APK")" "$(basename "$AAB")" > "$(basename "$SHA")"; shasum -a 256 -c "$(basename "$SHA")" )
install_connected_quest_devices
[[ "$PERSIST_BUILD_NUMBER" == 1 ]] && printf '%s\n' "$BUILD_NUMBER" > "$BUILD_NUMBER_FILE"
printf '\nRantlist Quest Bubblewrap release complete.\nAPK: %s\nAAB: %s\nSHA: %s\n' "$APK" "$AAB" "$SHA"
