#!/usr/bin/env bash
# Local website deployment profile loader. No SSH host/port is committed to Git.
set -Eeuo pipefail

RANTLIST_RELEASE_PROFILE="${RANTLIST_RELEASE_PROFILE:-$HOME/.config/workwork/rantlist-release.env}"
CUT_DEPLOY_SCRIPT="${CUT_DEPLOY_SCRIPT:-$HOME/Documents/works/srt-ass-caption-animator/deploy_homepage.sh}"

_rantlist_extract_cut_default() {
  local key="$1" file="$2" line value
  line="$(grep -E "^${key}=" "$file" | head -n 1 || true)"
  [[ -n "$line" ]] || return 0
  value="${line#*:-}"
  value="${value%%\}*}"
  printf '%s\n' "$value"
}

rantlist_ensure_release_profile() {
  if [[ -f "$RANTLIST_RELEASE_PROFILE" ]]; then
    return 0
  fi
  [[ -f "$CUT_DEPLOY_SCRIPT" ]] || {
    printf 'ERROR: Rantlist release profile is missing: %s\n' "$RANTLIST_RELEASE_PROFILE" >&2
    printf 'The automatic importer also could not find the existing Cut deploy script: %s\n' "$CUT_DEPLOY_SCRIPT" >&2
    return 1
  }

  local user host port dir owner chmod
  user="$(_rantlist_extract_cut_default REMOTE_USER "$CUT_DEPLOY_SCRIPT")"
  host="$(_rantlist_extract_cut_default REMOTE_HOST "$CUT_DEPLOY_SCRIPT")"
  port="$(_rantlist_extract_cut_default REMOTE_PORT "$CUT_DEPLOY_SCRIPT")"
  dir="$(_rantlist_extract_cut_default REMOTE_DIR "$CUT_DEPLOY_SCRIPT")"
  owner="$(_rantlist_extract_cut_default REMOTE_OWNER "$CUT_DEPLOY_SCRIPT")"
  chmod="$(_rantlist_extract_cut_default REMOTE_CHMOD "$CUT_DEPLOY_SCRIPT")"

  [[ -n "$user" && -n "$host" && -n "$port" && -n "$dir" ]] || {
    printf 'ERROR: Could not import SSH deployment settings from %s\n' "$CUT_DEPLOY_SCRIPT" >&2
    return 1
  }
  dir="${dir%/cut}/rantlist"

  mkdir -p "$(dirname "$RANTLIST_RELEASE_PROFILE")"
  umask 077
  {
    printf 'RANTLIST_REMOTE_USER=%q\n' "$user"
    printf 'RANTLIST_REMOTE_HOST=%q\n' "$host"
    printf 'RANTLIST_REMOTE_PORT=%q\n' "$port"
    printf 'RANTLIST_REMOTE_DIR=%q\n' "$dir"
    printf 'RANTLIST_REMOTE_OWNER=%q\n' "${owner:-www-data:www-data}"
    printf 'RANTLIST_REMOTE_CHMOD=%q\n' "${chmod:-Du=rwx,Dgo=rx,Fu=rw,Fgo=r}"
  } > "$RANTLIST_RELEASE_PROFILE"
  chmod 600 "$RANTLIST_RELEASE_PROFILE"
  printf 'Imported local Rantlist website deployment profile from the existing Cut release setup: %s\n' "$RANTLIST_RELEASE_PROFILE"
}

rantlist_load_release_profile() {
  rantlist_ensure_release_profile || return 1
  # shellcheck disable=SC1090
  source "$RANTLIST_RELEASE_PROFILE"
  : "${RANTLIST_REMOTE_USER:?RANTLIST_REMOTE_USER missing from release profile}"
  : "${RANTLIST_REMOTE_HOST:?RANTLIST_REMOTE_HOST missing from release profile}"
  : "${RANTLIST_REMOTE_PORT:?RANTLIST_REMOTE_PORT missing from release profile}"
  : "${RANTLIST_REMOTE_DIR:?RANTLIST_REMOTE_DIR missing from release profile}"
  RANTLIST_REMOTE_OWNER="${RANTLIST_REMOTE_OWNER:-www-data:www-data}"
  RANTLIST_REMOTE_CHMOD="${RANTLIST_REMOTE_CHMOD:-Du=rwx,Dgo=rx,Fu=rw,Fgo=r}"
}
