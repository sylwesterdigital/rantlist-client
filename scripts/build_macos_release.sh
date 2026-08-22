#!/usr/bin/env bash
# Rantlist macOS .app/.dmg builder. No server process or local port is bundled.
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="${APP_NAME:-Rantlist}"
APP_SAFE_NAME="${APP_SAFE_NAME:-Rantlist}"
BUNDLE_ID="${BUNDLE_ID:-fun.workwork.rantlist}"
MIN_MACOS="${MIN_MACOS:-12.0}"
MACOS_SIGN_IDENTITY="${MACOS_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
APP_ICON_SOURCE="${APP_ICON_SOURCE:-}"
BUILD_ARCHS="${BUILD_ARCHS:-arm64 x86_64}"
BUILD_NUMBER_OVERRIDE="${BUILD_NUMBER_OVERRIDE:-}"
PERSIST_BUILD_NUMBER="${PERSIST_BUILD_NUMBER:-1}"

BUILD_ROOT="$ROOT/.macos-build"
APP_ROOT="$BUILD_ROOT/${APP_NAME}.app"
CONTENTS="$APP_ROOT/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
RELEASE_DIR="$ROOT/release"
VERSION_FILE="$ROOT/VERSION.txt"
BUILD_NUMBER_FILE="$ROOT/BUILD_NUMBER.txt"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
retry_cmd(){ local attempts="$1" delay="$2"; shift 2; local n=1; until "$@"; do local c=$?; (( n >= attempts )) && return "$c"; warn "Command failed ($n/$attempts); retrying in ${delay}s: $*"; sleep "$delay"; n=$((n+1)); done; }

[[ "$(uname -s)" == "Darwin" ]] || die "This release builder must run on macOS."
for tool in xcrun swiftc hdiutil ditto codesign plutil lipo shasum; do
  command -v "$tool" >/dev/null 2>&1 || die "Missing required macOS tool: $tool"
done
[[ -f "$ROOT/macos/RantlistApp.swift" ]] || die "Missing macos/RantlistApp.swift"
[[ -f "$VERSION_FILE" ]] || die "VERSION.txt is missing. Run scripts/sync_from_stage.sh first."
[[ -f "$BUILD_NUMBER_FILE" ]] || printf '0\n' > "$BUILD_NUMBER_FILE"

command -v node >/dev/null 2>&1 || die "Node.js is required for the pre-release security scan."
log "Running public-repository security scan"
node "$ROOT/scripts/security_scan.js" "$ROOT"

APP_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
[[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid VERSION.txt: $APP_VERSION"
PREVIOUS_BUILD="$(tr -cd '0-9' < "$BUILD_NUMBER_FILE")"
PREVIOUS_BUILD="${PREVIOUS_BUILD:-0}"
if [[ -n "$BUILD_NUMBER_OVERRIDE" ]]; then
  [[ "$BUILD_NUMBER_OVERRIDE" =~ ^[1-9][0-9]*$ ]] || die "BUILD_NUMBER_OVERRIDE must be a positive integer."
  BUILD_NUMBER="$BUILD_NUMBER_OVERRIDE"
else
  BUILD_NUMBER="$((10#$PREVIOUS_BUILD + 1))"
fi
log "Version: $APP_VERSION (build $BUILD_NUMBER)"

rm -rf "$BUILD_ROOT"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$RELEASE_DIR" "$BUILD_ROOT/bin"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

log "Compiling native WKWebView client"
compiled=()
BUILD_ARCHS_NORMALIZED="${BUILD_ARCHS//,/ }"
IFS=$' \t\n' read -r -a REQUESTED_ARCHS <<< "$BUILD_ARCHS_NORMALIZED"
[[ ${#REQUESTED_ARCHS[@]} -gt 0 ]] || die "BUILD_ARCHS did not contain any architectures."
for arch in "${REQUESTED_ARCHS[@]}"; do
  [[ -n "$arch" ]] || continue
  case "$arch" in arm64|x86_64) ;; *) die "Unsupported BUILD_ARCHS entry: $arch" ;; esac
  out="$BUILD_ROOT/bin/Rantlist-$arch"
  xcrun swiftc -O -whole-module-optimization \
    -sdk "$SDK_PATH" \
    -target "$arch-apple-macos${MIN_MACOS}" \
    -framework Cocoa -framework WebKit \
    "$ROOT/macos/RantlistApp.swift" -o "$out" \
    || die "Swift compilation failed for $arch"
  compiled+=("$out")
done

[[ ${#compiled[@]} -gt 0 ]] || die "No macOS architecture was built."
if [[ ${#compiled[@]} -eq 1 ]]; then
  cp "${compiled[0]}" "$MACOS_DIR/$APP_NAME"
  ARCH_LABEL="$(basename "${compiled[0]}" | sed 's/^Rantlist-//')"
else
  lipo -create "${compiled[@]}" -output "$MACOS_DIR/$APP_NAME"
  ARCH_LABEL="universal2"
fi
chmod 755 "$MACOS_DIR/$APP_NAME"

ICON_PLIST=""
if [[ -n "$APP_ICON_SOURCE" ]]; then
  SOURCE="${APP_ICON_SOURCE/#\~/$HOME}"
  [[ -f "$SOURCE" ]] || die "APP_ICON_SOURCE does not exist: $SOURCE"
  case "${SOURCE##*.}" in
    icns|ICNS)
      cp "$SOURCE" "$RESOURCES_DIR/Rantlist.icns"
      ICON_PLIST='<key>CFBundleIconFile</key><string>Rantlist.icns</string>'
      ;;
    *) warn "APP_ICON_SOURCE currently accepts .icns. Build continues with the generic app icon." ;;
  esac
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDisplayName</key><string>$APP_NAME</string>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
<key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
<key>LSApplicationCategoryType</key><string>public.app-category.social-networking</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSCameraUsageDescription</key><string>Rantlist uses the camera when you choose video calls or camera capture.</string>
<key>NSMicrophoneUsageDescription</key><string>Rantlist uses the microphone when you choose calls, voice messages or recording.</string>
<key>NSAppTransportSecurity</key><dict>
  <key>NSAllowsArbitraryLoads</key><false/>
  <key>NSAllowsLocalNetworking</key><false/>
</dict>
$ICON_PLIST
</dict></plist>
PLIST
plutil -lint "$CONTENTS/Info.plist" >/dev/null

ENTITLEMENTS="$BUILD_ROOT/entitlements.plist"
cat > "$ENTITLEMENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.device.camera</key><true/>
<key>com.apple.security.device.audio-input</key><true/>
</dict></plist>
PLIST

log "Signing application"
if [[ -n "$MACOS_SIGN_IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$MACOS_SIGN_IDENTITY" "$APP_ROOT"
else
  codesign --force --entitlements "$ENTITLEMENTS" --sign - "$APP_ROOT"
fi
codesign --verify --deep --strict --verbose=2 "$APP_ROOT"

log "Verifying camera and microphone entitlements"
SIGNED_ENTITLEMENTS="$BUILD_ROOT/signed-entitlements.plist"
codesign -d --entitlements :- "$APP_ROOT" > "$SIGNED_ENTITLEMENTS" 2>/dev/null \
  || die "Could not read entitlements from signed Rantlist.app"
[[ -x /usr/libexec/PlistBuddy ]] || die "/usr/libexec/PlistBuddy is required to verify signed entitlements."
[[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.device.camera' "$SIGNED_ENTITLEMENTS" 2>/dev/null || true)" == "true" ]] \
  || die "Signed app is missing com.apple.security.device.camera entitlement."
[[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.device.audio-input' "$SIGNED_ENTITLEMENTS" 2>/dev/null || true)" == "true" ]] \
  || die "Signed app is missing com.apple.security.device.audio-input entitlement."

log "Running packaged smoke test"
"$MACOS_DIR/$APP_NAME" --smoke-test

if [[ -n "$NOTARY_PROFILE" ]]; then
  [[ -n "$MACOS_SIGN_IDENTITY" ]] || die "NOTARY_PROFILE requires MACOS_SIGN_IDENTITY."
  NOTARY_ZIP="$BUILD_ROOT/${APP_SAFE_NAME}-notary.zip"
  ditto -c -k --sequesterRsrc --keepParent "$APP_ROOT" "$NOTARY_ZIP"
  log "Submitting app bundle to Apple notarization service"
  retry_cmd 3 12 xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_ROOT"
  xcrun stapler validate "$APP_ROOT"
  /usr/sbin/spctl --assess --type execute --verbose=2 "$APP_ROOT"
else
  /usr/sbin/spctl --assess --type execute --verbose=2 "$APP_ROOT" || warn "Gatekeeper assessment is expected to fail for an ad-hoc/test build."
fi

ZIP_PATH="$RELEASE_DIR/${APP_SAFE_NAME}-v${APP_VERSION}-b${BUILD_NUMBER}-macOS-${ARCH_LABEL}.zip"
DMG_PATH="$RELEASE_DIR/${APP_SAFE_NAME}-v${APP_VERSION}-b${BUILD_NUMBER}-macOS-${ARCH_LABEL}.dmg"
CHECKSUM_PATH="$RELEASE_DIR/${APP_SAFE_NAME}-v${APP_VERSION}-b${BUILD_NUMBER}-SHA256.txt"
rm -f "$ZIP_PATH" "$DMG_PATH" "$CHECKSUM_PATH"

log "Creating release ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_ROOT" "$ZIP_PATH"

log "Creating drag-to-Applications DMG"
DMG_STAGE="$(mktemp -d)"
cleanup_dmg(){ rm -rf "$DMG_STAGE"; }
trap cleanup_dmg EXIT
ditto "$APP_ROOT" "$DMG_STAGE/${APP_NAME}.app"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_PATH" >/dev/null
cleanup_dmg
trap - EXIT

if [[ -n "$MACOS_SIGN_IDENTITY" ]]; then
  codesign --force --timestamp --sign "$MACOS_SIGN_IDENTITY" "$DMG_PATH"
fi
if [[ -n "$NOTARY_PROFILE" ]]; then
  log "Submitting DMG to Apple notarization service"
  retry_cmd 3 12 xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  /usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
fi

(
  cd "$RELEASE_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" "$(basename "$DMG_PATH")" > "$(basename "$CHECKSUM_PATH")"
  shasum -a 256 -c "$(basename "$CHECKSUM_PATH")"
)

if [[ "$PERSIST_BUILD_NUMBER" == "1" ]]; then
  printf '%s\n' "$BUILD_NUMBER" > "$BUILD_NUMBER_FILE"
fi

printf '\n\033[1;32mRantlist macOS release complete.\033[0m\n'
printf 'Version: %s\nBuild: %s\nApp: %s\nDMG: %s\nZIP: %s\nSHA: %s\n' \
  "$APP_VERSION" "$BUILD_NUMBER" "$APP_ROOT" "$DMG_PATH" "$ZIP_PATH" "$CHECKSUM_PATH"
if [[ -z "$MACOS_SIGN_IDENTITY" ]]; then
  printf '\nAd-hoc test build. Public distribution should use scripts/release_signed.sh.\n'
fi
