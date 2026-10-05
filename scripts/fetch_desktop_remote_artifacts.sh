#!/usr/bin/env bash
# Fetch remote desktop artifacts into a disposable Mac staging directory for GitHub upload.
set -Eeuo pipefail
IFS=$' \n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=desktop_remote_common.sh
source "$ROOT/scripts/desktop_remote_common.sh"
VERSION="${1:?version required}"; BUILD="${2:?build required}"; TAG="${3:?tag required}"; DEST="${4:?destination required}"; PLATFORMS="${5:?platform list required}"
rantlist_desktop_remote_config
mkdir -p "$DEST"
"$ROOT/scripts/validate_desktop_remote_artifacts.sh" "$VERSION" "$BUILD" "$TAG" "$PLATFORMS"
ART="$RANTLIST_DESKTOP_BUILD_ROOT/release-jobs/$TAG"
for p in $PLATFORMS; do
  case "$p" in
    linux) generator=desktop_linux_names;;
    windows) generator=desktop_windows_names;;
    *) remote_die "Unsupported remote platform: $p";;
  esac
  while IFS= read -r name; do
    desktop_remote_scp_from "$ART/$name" "$DEST/$name"
  done < <($generator "$VERSION" "$BUILD")
done
for sha in "$DEST"/*-SHA256.txt; do [[ -e "$sha" ]] || continue; (cd "$DEST" && shasum -a 256 -c "$(basename "$sha")") >/dev/null; done
