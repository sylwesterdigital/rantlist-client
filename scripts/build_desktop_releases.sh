#!/usr/bin/env bash
# Sequential, low-priority Windows + Linux desktop release build.
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
node "$ROOT/scripts/verify_desktop_client.js"
"$ROOT/scripts/build_linux_release.sh"
"$ROOT/scripts/build_windows_release.sh"
printf '\nDesktop release ZIPs:\n'
find "${RANTLIST_DESKTOP_RELEASE_ROOT:-/srv/rantlist-build/releases}" -maxdepth 1 -type f -name 'rantlist-*-v*.zip' -print | sort
