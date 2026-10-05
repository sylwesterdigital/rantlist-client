#!/usr/bin/env bash
# Read-only preflight for the dedicated Ubuntu desktop build worker.
set -Eeuo pipefail
IFS=$' \n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=desktop_remote_common.sh
source "$ROOT/scripts/desktop_remote_common.sh"
rantlist_desktop_remote_config

remote_log "Checking Ubuntu desktop build worker $RANTLIST_DESKTOP_BUILD_HOST:$RANTLIST_DESKTOP_BUILD_PORT"
desktop_remote_ssh "bash -s -- '$RANTLIST_DESKTOP_BUILD_ROOT' '$RANTLIST_DESKTOP_BUILD_USER'" <<'REMOTE'
set -Eeuo pipefail
base="$1"; build_user="$2"
[[ "$(uname -s)" == Linux ]] || { echo 'ERROR: desktop build worker is not Linux.' >&2; exit 1; }
[[ "$(uname -m)" == x86_64 ]] || { echo 'ERROR: desktop build worker is not x86_64.' >&2; exit 1; }
[[ -d "$base" ]] || { echo "ERROR: build root missing: $base" >&2; exit 1; }
id "$build_user" >/dev/null 2>&1 || { echo "ERROR: build user missing: $build_user" >&2; exit 1; }
for t in runuser node npm zip unzip sha256sum tar realpath makensis; do command -v "$t" >/dev/null 2>&1 || { echo "ERROR: missing build-worker tool: $t" >&2; exit 1; }; done
free_kb="$(df -Pk "$base" | awk 'NR==2{print $4}')"
[[ "$free_kb" =~ ^[0-9]+$ ]] || exit 1
(( free_kb >= 5*1024*1024 )) || { echo 'ERROR: less than 5GB free on desktop build worker.' >&2; exit 1; }
printf 'desktop-worker-ok free-kb=%s node=%s nsis=%s\n' "$free_kb" "$(node --version)" "$(makensis -VERSION 2>/dev/null || true)"
REMOTE
