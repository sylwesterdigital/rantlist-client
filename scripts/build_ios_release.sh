#!/usr/bin/env bash
# Build signed iOS archive and App Store-style IPA using Xcode automatic signing.
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
IOS_DIR="$ROOT/mobile/ios"
RELEASE_DIR="$ROOT/release"
BUILD_ROOT="$ROOT/.ios-build"
VERSION_FILE="$ROOT/VERSION.txt"
BUILD_NUMBER_FILE="$ROOT/BUILD_NUMBER.txt"
BUILD_NUMBER_OVERRIDE="${BUILD_NUMBER_OVERRIDE:-}"
PERSIST_BUILD_NUMBER="${PERSIST_BUILD_NUMBER:-1}"
TEAM_ID="${RANTLIST_APPLE_TEAM_ID:-5P9V78UZAC}"
BUNDLE_ID="${RANTLIST_IOS_BUNDLE_ID:-fun.workwork.rantlist}"
log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
"$ROOT/scripts/check_ios_release_credentials.sh" >/dev/null
[[ -f "$VERSION_FILE" ]] || die "VERSION.txt is missing."
[[ -f "$BUILD_NUMBER_FILE" ]] || printf '0\n' > "$BUILD_NUMBER_FILE"
APP_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
[[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid VERSION.txt: $APP_VERSION"
PREVIOUS_BUILD="$(tr -cd '0-9' < "$BUILD_NUMBER_FILE")"; PREVIOUS_BUILD="${PREVIOUS_BUILD:-0}"
if [[ -n "$BUILD_NUMBER_OVERRIDE" ]]; then BUILD_NUMBER="$BUILD_NUMBER_OVERRIDE"; else BUILD_NUMBER="$((10#$PREVIOUS_BUILD + 1))"; fi
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || die "Invalid build number: $BUILD_NUMBER"
rm -rf "$BUILD_ROOT"; mkdir -p "$BUILD_ROOT/export" "$RELEASE_DIR"
ARCHIVE="$BUILD_ROOT/Rantlist.xcarchive"
EXPORT_OPTIONS="$BUILD_ROOT/ExportOptions.plist"
cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>signingStyle</key><string>automatic</string>
<key>teamID</key><string>$TEAM_ID</string>
<key>uploadSymbols</key><true/>
<key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST
log "Archiving iOS app with automatic signing"
xcodebuild -project "$IOS_DIR/Rantlist.xcodeproj" -scheme Rantlist -configuration Release -sdk iphoneos \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$TEAM_ID" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  MARKETING_VERSION="$APP_VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates archive
log "Exporting iOS IPA"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$BUILD_ROOT/export" \
  -exportOptionsPlist "$EXPORT_OPTIONS" -allowProvisioningUpdates
IPA_SRC="$(find "$BUILD_ROOT/export" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
[[ -n "$IPA_SRC" && -s "$IPA_SRC" ]] || die "Xcode export did not produce an IPA. Confirm this team has iOS/App Store distribution configured in Xcode."
IPA="$RELEASE_DIR/Rantlist-v${APP_VERSION}-b${BUILD_NUMBER}-iOS.ipa"
SHA="$RELEASE_DIR/Rantlist-v${APP_VERSION}-b${BUILD_NUMBER}-iOS-SHA256.txt"
cp "$IPA_SRC" "$IPA"
( cd "$RELEASE_DIR"; shasum -a 256 "$(basename "$IPA")" > "$(basename "$SHA")"; shasum -a 256 -c "$(basename "$SHA")" )
[[ "$PERSIST_BUILD_NUMBER" == 1 ]] && printf '%s\n' "$BUILD_NUMBER" > "$BUILD_NUMBER_FILE"
printf '\nRantlist iOS release complete.\nIPA: %s\nSHA: %s\n' "$IPA" "$SHA"
