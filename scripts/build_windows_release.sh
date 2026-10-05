#!/usr/bin/env bash
# Build Windows x64 Electron application + native Linux NSIS installer.
# This intentionally avoids Docker, system changes and 32-bit Wine requirements.
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=desktop_build_common.sh
source "$ROOT/scripts/desktop_build_common.sh"
assert_desktop_build_host
prepare_desktop_node_modules
command -v makensis >/dev/null 2>&1 || die "NSIS compiler (makensis) is not installed."

VERSION="$(version_value)"
BUILD_NUMBER="${BUILD_NUMBER_OVERRIDE:-}"
if [[ -n "$BUILD_NUMBER" ]]; then [[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || die "Invalid BUILD_NUMBER_OVERRIDE: $BUILD_NUMBER"; RELEASE_STEM="Rantlist-v${VERSION}-b${BUILD_NUMBER}"; else RELEASE_STEM="Rantlist-v${VERSION}"; fi
OUT="$BUILD_ROOT/dist-windows"
PLATFORM_RELEASE="$RELEASE_ROOT/windows-v$VERSION${BUILD_NUMBER:+-b$BUILD_NUMBER}"
ZIP_OUT="$RELEASE_ROOT/rantlist-windows-v${VERSION}${BUILD_NUMBER:+-b$BUILD_NUMBER}-x64.zip"
rm -rf "$OUT" "$PLATFORM_RELEASE"
mkdir -p "$OUT" "$PLATFORM_RELEASE"

log "Packaging Rantlist Windows $VERSION (x64) without running Windows binaries"
(
  cd "$DESKTOP_ROOT"
  RANTLIST_DESKTOP_OUTPUT="$OUT" CSC_IDENTITY_AUTO_DISCOVERY=false \
    ./node_modules/.bin/electron-builder --config electron-builder.config.cjs --win --x64 --dir
)

UNPACKED="$(find "$OUT" -maxdepth 1 -type d -name 'win-unpacked' -print -quit)"
[[ -d "$UNPACKED" && -s "$UNPACKED/Rantlist.exe" ]] || die "Windows unpacked application was not produced."

PORTABLE="$PLATFORM_RELEASE/${RELEASE_STEM}-windows-x64-portable.zip"
SETUP="$PLATFORM_RELEASE/${RELEASE_STEM}-windows-x64-Setup.exe"
(
  cd "$UNPACKED"
  zip -q -9 -r "$PORTABLE" .
)

log "Creating Windows NSIS installer with the native Linux makensis compiler"
makensis \
  -DAPP_VERSION="$VERSION" \
  -DSOURCE_DIR="$UNPACKED" \
  -DOUT_FILE="$SETUP" \
  -DICON_FILE="$DESKTOP_ROOT/assets/icon.ico" \
  "$DESKTOP_ROOT/installer/windows.nsi" >/dev/null
[[ -s "$SETUP" ]] || die "Windows NSIS installer was not produced."

(
  cd "$PLATFORM_RELEASE"
  SHA_FILE="${RELEASE_STEM}-windows-SHA256.txt"
  sha256sum "$(basename "$SETUP")" "$(basename "$PORTABLE")" > "$SHA_FILE"
  sha256sum -c "$SHA_FILE"
)
rm -f "$ZIP_OUT"
(cd "$PLATFORM_RELEASE" && zip -q -9 "$ZIP_OUT" ./*)
[[ -s "$ZIP_OUT" ]] || die "Windows release ZIP was not produced."
log "Windows release complete: $ZIP_OUT"
