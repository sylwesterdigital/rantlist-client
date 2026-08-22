#!/usr/bin/env bash
# WORKWORK.FUN signed/notarized Rantlist wrapper. Uses the same Apple credentials as Cut.
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

SIGNING_FINGERPRINT="${RANTLIST_SIGNING_FINGERPRINT:-B97863CA4E17170FCD5FBFA4C76A8DF3D91D5F6B}"
NOTARY_PROFILE="${RANTLIST_NOTARY_PROFILE:-workwork-caption-notary}"

log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == Darwin ]] || die "Signed releases must run on macOS."
command -v security >/dev/null 2>&1 || die "security tool is missing."
command -v xcrun >/dev/null 2>&1 || die "xcrun is missing."

IDENTITY_LINE="$(security find-identity -v -p codesigning 2>/dev/null | grep -F "$SIGNING_FINGERPRINT" | head -n 1 || true)"
[[ -n "$IDENTITY_LINE" ]] || die "WORKWORK.FUN Developer ID fingerprint $SIGNING_FINGERPRINT is not available in this Mac Keychain."
IDENTITY_NAME="$(printf '%s\n' "$IDENTITY_LINE" | sed -nE 's/.*"([^"]+)".*/\1/p')"
log "Developer ID: ${IDENTITY_NAME:-$SIGNING_FINGERPRINT}"

log "Validating Apple notarization profile: $NOTARY_PROFILE"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --output-format json >/dev/null 2>&1 \
  || die "Existing Apple notarization profile '$NOTARY_PROFILE' is not usable on this Mac."

MACOS_SIGN_IDENTITY="$SIGNING_FINGERPRINT" \
NOTARY_PROFILE="$NOTARY_PROFILE" \
APP_NAME="Rantlist" \
APP_SAFE_NAME="Rantlist" \
BUNDLE_ID="fun.workwork.rantlist" \
BUILD_ARCHS="${BUILD_ARCHS:-arm64 x86_64}" \
"$ROOT/scripts/build_macos_release.sh"
