#!/usr/bin/env bash
# Best-effort removal of one completed desktop build job after GitHub/homepage success.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=desktop_remote_common.sh
source "$ROOT/scripts/desktop_remote_common.sh"
TAG="${1:?tag required}"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-b[1-9][0-9]*$ ]] || remote_die "Invalid release tag: $TAG"
rantlist_desktop_remote_config
desktop_remote_ssh "rm -rf -- '$RANTLIST_DESKTOP_BUILD_ROOT/jobs/$TAG' '$RANTLIST_DESKTOP_BUILD_ROOT/release-jobs/$TAG'"
