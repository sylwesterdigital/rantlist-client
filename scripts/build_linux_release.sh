#!/usr/bin/env bash
# Build Linux x86_64 AppImage + DEB without touching system services or packages.
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=desktop_build_common.sh
source "$ROOT/scripts/desktop_build_common.sh"
assert_desktop_build_host
prepare_desktop_node_modules

VERSION="$(version_value)"
BUILD_NUMBER="${BUILD_NUMBER_OVERRIDE:-}"
if [[ -n "$BUILD_NUMBER" ]]; then [[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || die "Invalid BUILD_NUMBER_OVERRIDE: $BUILD_NUMBER"; RELEASE_STEM="Rantlist-v${VERSION}-b${BUILD_NUMBER}"; else RELEASE_STEM="Rantlist-v${VERSION}"; fi
OUT="$BUILD_ROOT/dist-linux"
PLATFORM_RELEASE="$RELEASE_ROOT/linux-v$VERSION${BUILD_NUMBER:+-b$BUILD_NUMBER}"
ZIP_OUT="$RELEASE_ROOT/rantlist-linux-v${VERSION}${BUILD_NUMBER:+-b$BUILD_NUMBER}-x86_64.zip"
rm -rf "$OUT" "$PLATFORM_RELEASE"
mkdir -p "$OUT" "$PLATFORM_RELEASE"

log "Building Rantlist Linux $VERSION (x86_64)"
(
  cd "$DESKTOP_ROOT"
  RANTLIST_DESKTOP_OUTPUT="$OUT" ./node_modules/.bin/electron-builder \
    --config electron-builder.config.cjs --linux AppImage deb --x64
)

APPIMAGE="$(find "$OUT" -maxdepth 1 -type f -name 'Rantlist-*-linux-x86_64.AppImage' -print -quit)"
DEB="$(find "$OUT" -maxdepth 1 -type f -name 'rantlist_*_amd64.deb' -print -quit)"
[[ -s "$APPIMAGE" ]] || die "Linux AppImage was not produced."
[[ -s "$DEB" ]] || die "Linux DEB was not produced."
APPIMAGE_OUT="$PLATFORM_RELEASE/${RELEASE_STEM}-linux-x86_64.AppImage"
DEB_OUT="$PLATFORM_RELEASE/${RELEASE_STEM}-linux-amd64.deb"
cp "$APPIMAGE" "$APPIMAGE_OUT"
cp "$DEB" "$DEB_OUT"

if command -v xvfb-run >/dev/null 2>&1; then
  UNPACKED="$(find "$OUT" -maxdepth 1 -type d -name 'linux-unpacked' -print -quit)"
  if [[ -x "$UNPACKED/rantlist" ]]; then
    log "Running low-priority packaged Linux smoke test"
    timeout 30s xvfb-run -a "$UNPACKED/rantlist" --smoke-test
  else
    warn "linux-unpacked/rantlist was not available for smoke test."
  fi
fi

(
  cd "$PLATFORM_RELEASE"
  SHA_FILE="${RELEASE_STEM}-linux-SHA256.txt"
  sha256sum "$(basename "$APPIMAGE_OUT")" "$(basename "$DEB_OUT")" > "$SHA_FILE"
  sha256sum -c "$SHA_FILE"
)
rm -f "$ZIP_OUT"
(cd "$PLATFORM_RELEASE" && zip -q -9 "$ZIP_OUT" ./*)
[[ -s "$ZIP_OUT" ]] || die "Linux release ZIP was not produced."
log "Linux release complete: $ZIP_OUT"
