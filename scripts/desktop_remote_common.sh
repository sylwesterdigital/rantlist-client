#!/usr/bin/env bash
# Mac-side helpers for the dedicated Ubuntu Windows/Linux build worker.
set -Eeuo pipefail
IFS=$' \n\t'
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=release_profile.sh
source "$ROOT/scripts/release_profile.sh"

remote_log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
remote_die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

rantlist_desktop_remote_config(){
  rantlist_load_release_profile || return 1
  RANTLIST_DESKTOP_BUILD_HOST="${RANTLIST_DESKTOP_BUILD_HOST:-$RANTLIST_REMOTE_HOST}"
  RANTLIST_DESKTOP_BUILD_PORT="${RANTLIST_DESKTOP_BUILD_PORT:-$RANTLIST_REMOTE_PORT}"
  RANTLIST_DESKTOP_BUILD_SSH_USER="${RANTLIST_DESKTOP_BUILD_SSH_USER:-root}"
  RANTLIST_DESKTOP_BUILD_USER="${RANTLIST_DESKTOP_BUILD_USER:-rantbuild}"
  RANTLIST_DESKTOP_BUILD_ROOT="${RANTLIST_DESKTOP_BUILD_ROOT:-/srv/rantlist-build}"
  export RANTLIST_DESKTOP_BUILD_HOST RANTLIST_DESKTOP_BUILD_PORT RANTLIST_DESKTOP_BUILD_SSH_USER RANTLIST_DESKTOP_BUILD_USER RANTLIST_DESKTOP_BUILD_ROOT
}

desktop_remote_ssh(){
  ssh -o BatchMode=yes -o ConnectTimeout=15 -p "$RANTLIST_DESKTOP_BUILD_PORT" \
    "$RANTLIST_DESKTOP_BUILD_SSH_USER@$RANTLIST_DESKTOP_BUILD_HOST" "$@"
}

desktop_remote_scp_to(){
  local source="$1" destination="$2"
  scp -q -o BatchMode=yes -o ConnectTimeout=15 -P "$RANTLIST_DESKTOP_BUILD_PORT" \
    "$source" "$RANTLIST_DESKTOP_BUILD_SSH_USER@$RANTLIST_DESKTOP_BUILD_HOST:$destination"
}

desktop_remote_scp_from(){
  local source="$1" destination="$2"
  scp -q -o BatchMode=yes -o ConnectTimeout=15 -P "$RANTLIST_DESKTOP_BUILD_PORT" \
    "$RANTLIST_DESKTOP_BUILD_SSH_USER@$RANTLIST_DESKTOP_BUILD_HOST:$source" "$destination"
}

desktop_release_base(){
  local version="$1" build="$2"
  printf 'Rantlist-v%s-b%s' "$version" "$build"
}

desktop_linux_names(){
  local base; base="$(desktop_release_base "$1" "$2")"
  printf '%s\n' "${base}-linux-x86_64.AppImage" "${base}-linux-amd64.deb" "${base}-linux-SHA256.txt"
}

desktop_windows_names(){
  local base; base="$(desktop_release_base "$1" "$2")"
  printf '%s\n' "${base}-windows-x64-Setup.exe" "${base}-windows-x64-portable.zip" "${base}-windows-SHA256.txt"
}
