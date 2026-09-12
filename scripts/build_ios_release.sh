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
# auto: try the real Share Extension first and fall back only when Apple's
# provisioning profile has not yet been assigned the required App Group.
# full: require App Group provisioning and fail rather than falling back.
# off: build the APNs/badge-capable containing app without the Share Extension.
IOS_SHARE_MODE="${RANTLIST_IOS_SHARE_MODE:-auto}"
INSTALL_CONNECTED="${RANTLIST_IOS_INSTALL_CONNECTED:-1}"
log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
"$ROOT/scripts/check_ios_release_credentials.sh" >/dev/null
[[ -f "$VERSION_FILE" ]] || die "VERSION.txt is missing."
[[ -f "$BUILD_NUMBER_FILE" ]] || printf '0\n' > "$BUILD_NUMBER_FILE"
APP_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
[[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid VERSION.txt: $APP_VERSION"
PREVIOUS_BUILD="$(tr -cd '0-9' < "$BUILD_NUMBER_FILE")"; PREVIOUS_BUILD="${PREVIOUS_BUILD:-0}"
if [[ -n "$BUILD_NUMBER_OVERRIDE" ]]; then BUILD_NUMBER="$BUILD_NUMBER_OVERRIDE"; else BUILD_NUMBER="$((10#$PREVIOUS_BUILD + 1))"; fi
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || die "Invalid build number: $BUILD_NUMBER"
case "$IOS_SHARE_MODE" in auto|full|off) ;; *) die "RANTLIST_IOS_SHARE_MODE must be auto, full, or off (got: $IOS_SHARE_MODE)" ;; esac
rm -rf "$BUILD_ROOT"; mkdir -p "$BUILD_ROOT/export" "$RELEASE_DIR"
ARCHIVE="$BUILD_ROOT/Rantlist.xcarchive"
EXPORT_OPTIONS="$BUILD_ROOT/ExportOptions.plist"
ARCHIVE_LOG="$BUILD_ROOT/archive-full.log"
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

archive_project() {
  local project_dir="$1"
  xcodebuild -project "$project_dir/Rantlist.xcodeproj" -scheme Rantlist -configuration Release -sdk iphoneos \
    -archivePath "$ARCHIVE" \
    DEVELOPMENT_TEAM="$TEAM_ID" RANTLIST_APP_BUNDLE_ID="$BUNDLE_ID" \
    MARKETING_VERSION="$APP_VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates archive
}

install_connected_ios_devices() {
  [[ "$INSTALL_CONNECTED" == "1" ]] || { log "Connected-device install disabled (RANTLIST_IOS_INSTALL_CONNECTED=$INSTALL_CONNECTED)"; return 0; }
  command -v xcrun >/dev/null 2>&1 || { warn "xcrun is unavailable; skipping connected iPhone install."; return 0; }
  local app_path="$ARCHIVE/Products/Applications/Rantlist.app"
  [[ -d "$app_path" ]] || { warn "Archived Rantlist.app not found; skipping connected iPhone install."; return 0; }
  local devices_json="$BUILD_ROOT/xcdevice-list.json"
  if ! xcrun xcdevice list --timeout 3 > "$devices_json" 2>/dev/null; then
    warn "Could not enumerate connected iOS development devices; IPA release will continue."
    return 0
  fi
  local devices
  devices="$(/usr/bin/python3 - "$devices_json" <<'PYDEV'
import json, sys
try:
    items=json.load(open(sys.argv[1]))
except Exception:
    items=[]
for item in items if isinstance(items,list) else []:
    if item.get('simulator'):
        continue
    if not item.get('available', False):
        continue
    platform=str(item.get('platform') or '').lower()
    if 'iphoneos' not in platform and platform not in ('ios','iphone'):
        continue
    ident=str(item.get('identifier') or '').strip()
    if not ident:
        continue
    name=str(item.get('name') or 'iOS device').replace('|',' ')
    print(f"{ident}|{name}")
PYDEV
)"
  if [[ -z "$devices" ]]; then
    warn "No connected/unlocked physical iOS development device found; IPA was built but not installed."
    return 0
  fi
  while IFS='|' read -r device_id device_name; do
    [[ -n "$device_id" ]] || continue
    log "Installing Rantlist $APP_VERSION build $BUILD_NUMBER on connected device: $device_name ($device_id)"
    if xcrun devicectl device install app --device "$device_id" "$app_path"; then
      log "Installed Rantlist on $device_name"
      if ! xcrun devicectl device process launch --device "$device_id" "$BUNDLE_ID" >/dev/null 2>&1; then
        warn "Rantlist installed on $device_name but could not be launched automatically."
      else
        log "Launched Rantlist on $device_name"
      fi
    else
      warn "Could not install Rantlist on $device_name; IPA release will continue."
    fi
  done <<< "$devices"
}

build_push_only_fallback() {
  local fallback_ios="$BUILD_ROOT/ios-push-only"
  rm -rf "$ARCHIVE" "$BUILD_ROOT/export" "$fallback_ios"
  mkdir -p "$BUILD_ROOT/export" "$fallback_ios"
  # ditto preserves the Xcode project bundle exactly and is available on every
  # macOS/Xcode release host used by this workflow.
  ditto "$IOS_DIR" "$fallback_ios"
  node "$ROOT/scripts/make_ios_push_only_project.js" "$fallback_ios"
  log "Retrying iOS archive with APNs/badges enabled and Share Extension omitted"
  archive_project "$fallback_ios"
  printf 'push-only\n' > "$BUILD_ROOT/ios-share-result.txt"
}

if [[ "$IOS_SHARE_MODE" == "off" ]]; then
  log "Archiving iOS app (Share Extension disabled by RANTLIST_IOS_SHARE_MODE=off)"
  build_push_only_fallback
else
  log "Archiving iOS app with automatic signing"
  set +e
  archive_project "$IOS_DIR" 2>&1 | tee "$ARCHIVE_LOG"
  archive_status=${PIPESTATUS[0]}
  set -e
  if [[ "$archive_status" -eq 0 ]]; then
    printf 'full\n' > "$BUILD_ROOT/ios-share-result.txt"
  elif grep -q 'com.apple.security.application-groups' "$ARCHIVE_LOG"; then
    if [[ "$IOS_SHARE_MODE" == "full" ]]; then
      die "Apple provisioning does not yet include App Group group.fun.workwork.rantlist. Register/assign that App Group to $BUNDLE_ID and $BUNDLE_ID.share, refresh signing, then rerun."
    fi
    warn "Apple provisioning does not yet include App Group group.fun.workwork.rantlist for the app + Share Extension."
    warn "This release will keep APNs/unread app-icon badges and automatically omit only the Share Extension."
    warn "To ship Share to Rantlist, register/assign group.fun.workwork.rantlist to $BUNDLE_ID and $BUNDLE_ID.share in the Apple Developer account, then rerun with RANTLIST_IOS_SHARE_MODE=full."
    build_push_only_fallback
  else
    exit "$archive_status"
  fi
fi

log "Exporting iOS IPA"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$BUILD_ROOT/export" \
  -exportOptionsPlist "$EXPORT_OPTIONS" -allowProvisioningUpdates
IPA_SRC="$(find "$BUILD_ROOT/export" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
[[ -n "$IPA_SRC" && -s "$IPA_SRC" ]] || die "Xcode export did not produce an IPA. Confirm this team has iOS/App Store distribution configured in Xcode."
IPA="$RELEASE_DIR/Rantlist-v${APP_VERSION}-b${BUILD_NUMBER}-iOS.ipa"
SHA="$RELEASE_DIR/Rantlist-v${APP_VERSION}-b${BUILD_NUMBER}-iOS-SHA256.txt"
cp "$IPA_SRC" "$IPA"
( cd "$RELEASE_DIR"; shasum -a 256 "$(basename "$IPA")" > "$(basename "$SHA")"; shasum -a 256 -c "$(basename "$SHA")" )
install_connected_ios_devices
[[ "$PERSIST_BUILD_NUMBER" == 1 ]] && printf '%s\n' "$BUILD_NUMBER" > "$BUILD_NUMBER_FILE"
share_result="$(cat "$BUILD_ROOT/ios-share-result.txt" 2>/dev/null || printf 'unknown')"
printf '\nRantlist iOS release complete.\nIPA: %s\nSHA: %s\niOS share mode: %s\n' "$IPA" "$SHA" "$share_result"
