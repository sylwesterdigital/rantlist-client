#!/usr/bin/env bash
set -Eeuo pipefail
die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || die "iOS release requires macOS."
for t in xcodebuild xcrun security; do command -v "$t" >/dev/null 2>&1 || die "Required iOS release tool missing: $t"; done
xcodebuild -version >/dev/null
TEAM_ID="${RANTLIST_APPLE_TEAM_ID:-5P9V78UZAC}"
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || die "Invalid RANTLIST_APPLE_TEAM_ID: $TEAM_ID"
printf 'iOS build prerequisites found. Xcode automatic signing will validate the iOS/App Store provisioning during archive/export.\n'
