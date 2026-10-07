#!/usr/bin/env bash
# Shared safety/runtime helpers for Rantlist desktop builds on the dedicated Ubuntu build host.
set -Eeuo pipefail
IFS=$'\n\t'

DESKTOP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../desktop" && pwd)"
ROOT="$(cd "$DESKTOP_ROOT/.." && pwd)"
SAFE_BASE="${RANTLIST_DESKTOP_SAFE_BASE:-/srv/rantlist-build}"
BUILD_ROOT="$ROOT/.desktop-build"
CACHE_ROOT="${RANTLIST_DESKTOP_CACHE_ROOT:-$SAFE_BASE/cache}"
RELEASE_ROOT="${RANTLIST_DESKTOP_RELEASE_ROOT:-$SAFE_BASE/releases}"

log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

assert_desktop_build_host(){
  [[ "$(uname -s)" == Linux ]] || die "Desktop cross-build scripts are intended for the Ubuntu build host."
  [[ "$(uname -m)" == x86_64 ]] || die "Desktop release target requires an x86_64 build host."
  [[ "$(id -u)" -ne 0 ]] || die "Refusing to build as root. Run as the dedicated rantbuild user."

  local real_root real_safe
  real_root="$(realpath -m "$ROOT")"
  real_safe="$(realpath -m "$SAFE_BASE")"
  case "$real_root/" in
    "$real_safe"/*) ;;
    *) [[ "${RANTLIST_ALLOW_EXTERNAL_BUILD_ROOT:-0}" == 1 ]] || die "Refusing to build outside $real_safe. Copy/extract the client under $real_safe first." ;;
  esac

  for tool in node npm zip sha256sum realpath; do command -v "$tool" >/dev/null 2>&1 || die "Required tool missing: $tool"; done
  local version desktop_version
  version="$(tr -d '[:space:]' < "$ROOT/VERSION.txt")"
  desktop_version="$(node -p "require('$DESKTOP_ROOT/package.json').version")"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid VERSION.txt: $version"
  [[ "$desktop_version" == "$version" ]] || die "desktop/package.json version ($desktop_version) does not match VERSION.txt ($version)."

  local free_kb
  free_kb="$(df -Pk "$SAFE_BASE" | awk 'NR==2{print $4}')"
  [[ "$free_kb" =~ ^[0-9]+$ ]] || die "Could not determine free disk space."
  if (( free_kb < 5*1024*1024 )); then
    local free_human
    free_human="$(awk -v kb="$free_kb" 'BEGIN { if (kb >= 1048576) printf "%.2f GiB", kb/1048576; else printf "%.0f MiB", kb/1024 }')"
    printf '\033[1;31m============================================================\n' >&2
    printf 'DESKTOP BUILD STOPPED — NOT ENOUGH STORAGE\n' >&2
    printf 'Worker build root: %s\n' "$SAFE_BASE" >&2
    printf 'Available: %s\n' "$free_human" >&2
    printf 'Required minimum: 5.00 GiB\n' >&2
    printf 'Free space on the Ubuntu build worker before retrying.\n' >&2
    printf '============================================================\033[0m\n' >&2
    exit 1
  fi

  mkdir -p "$BUILD_ROOT/tmp" "$CACHE_ROOT/npm" "$CACHE_ROOT/electron" "$CACHE_ROOT/electron-builder" "$RELEASE_ROOT"
  export TMPDIR="$BUILD_ROOT/tmp"
  export npm_config_cache="$CACHE_ROOT/npm"
  export ELECTRON_CACHE="$CACHE_ROOT/electron"
  export ELECTRON_BUILDER_CACHE="$CACHE_ROOT/electron-builder"
  export npm_config_audit=false npm_config_fund=false npm_config_update_notifier=false
  export MAKEFLAGS="${MAKEFLAGS:--j2}"
  export UV_THREADPOOL_SIZE="${UV_THREADPOOL_SIZE:-2}"
  export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=2048}"
  umask 022
  renice 15 -p $$ >/dev/null 2>&1 || true
  command -v ionice >/dev/null 2>&1 && ionice -c2 -n7 -p $$ >/dev/null 2>&1 || true
}

prepare_desktop_node_modules(){
  if [[ ! -x "$DESKTOP_ROOT/node_modules/.bin/electron-builder" || ! -x "$DESKTOP_ROOT/node_modules/.bin/electron" ]]; then
    log "Installing pinned Electron build dependencies locally (no global/system packages)"
    (cd "$DESKTOP_ROOT" && npm install --no-audit --no-fund --package-lock=false)
  fi
}

version_value(){ tr -d '[:space:]' < "$ROOT/VERSION.txt"; }
