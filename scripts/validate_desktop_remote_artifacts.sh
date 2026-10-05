#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$' \n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=desktop_remote_common.sh
source "$ROOT/scripts/desktop_remote_common.sh"
VERSION="${1:?version required}"; BUILD="${2:?build required}"; TAG="${3:?tag required}"; PLATFORMS="${4:?platform list required}"
rantlist_desktop_remote_config
ART="$RANTLIST_DESKTOP_BUILD_ROOT/release-jobs/$TAG"
names=()
for p in $PLATFORMS; do
  case "$p" in
    linux) while IFS= read -r n; do names+=("$n"); done < <(desktop_linux_names "$VERSION" "$BUILD");;
    windows) while IFS= read -r n; do names+=("$n"); done < <(desktop_windows_names "$VERSION" "$BUILD");;
    *) remote_die "Unsupported remote platform: $p";;
  esac
done
quoted=""
for n in "${names[@]}"; do printf -v q '%q' "$n"; quoted+=" $q"; done
desktop_remote_ssh "bash -s -- '$ART'$quoted" <<'REMOTE'
set -Eeuo pipefail
art="$1"; shift
[[ -d "$art" ]] || exit 1
for n in "$@"; do [[ -s "$art/$n" ]] || { echo "Missing remote desktop artifact: $n" >&2; exit 1; }; done
cd "$art"
for sha in *-SHA256.txt; do [[ -s "$sha" ]] && sha256sum -c "$sha" >/dev/null; done
REMOTE
