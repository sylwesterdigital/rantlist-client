#!/usr/bin/env bash
# Build selected Linux/Windows artifacts on the dedicated Ubuntu worker.
# No package installation, service control, Docker, or production-path access.
set -Eeuo pipefail
IFS=$' \n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=desktop_remote_common.sh
source "$ROOT/scripts/desktop_remote_common.sh"

VERSION="${1:?version required}"
BUILD="${2:?build required}"
TAG="${3:?tag required}"
PLATFORMS="${4:?platform list required}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || remote_die "Invalid version: $VERSION"
[[ "$BUILD" =~ ^[1-9][0-9]*$ ]] || remote_die "Invalid build: $BUILD"
[[ "$TAG" == "v${VERSION}-b${BUILD}" ]] || remote_die "Tag/version/build mismatch: $TAG"
for p in $PLATFORMS; do case "$p" in linux|windows) ;; *) remote_die "Unsupported remote platform: $p";; esac; done

rantlist_desktop_remote_config
"$ROOT/scripts/check_desktop_build_worker.sh"

ARCHIVE="$(mktemp "${TMPDIR:-/tmp}/rantlist-desktop-source.XXXXXX.tar.gz")"
cleanup(){ rm -f "$ARCHIVE"; }
trap cleanup EXIT

remote_log "Packing exact verified client source for $TAG"
COPYFILE_DISABLE=1 tar -C "$ROOT" -czf "$ARCHIVE" \
  --exclude='./.git' \
  --exclude='./release' \
  --exclude='./.macos-build' \
  --exclude='./.ios-build' \
  --exclude='./.android-build' \
  --exclude='./.desktop-build' \
  --exclude='./desktop/node_modules' \
  --exclude='./mobile/android/.gradle' \
  --exclude='./mobile/android/*/build' \
  .
SOURCE_SHA="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
REMOTE_INCOMING="$RANTLIST_DESKTOP_BUILD_ROOT/incoming/${TAG}-${SOURCE_SHA}.tar.gz"

desktop_remote_ssh "install -d -o '$RANTLIST_DESKTOP_BUILD_USER' -g '$RANTLIST_DESKTOP_BUILD_USER' '$RANTLIST_DESKTOP_BUILD_ROOT/incoming' '$RANTLIST_DESKTOP_BUILD_ROOT/jobs' '$RANTLIST_DESKTOP_BUILD_ROOT/release-jobs'"
desktop_remote_scp_to "$ARCHIVE" "$REMOTE_INCOMING.tmp"
desktop_remote_ssh "chown '$RANTLIST_DESKTOP_BUILD_USER:$RANTLIST_DESKTOP_BUILD_USER' '$REMOTE_INCOMING.tmp' && mv '$REMOTE_INCOMING.tmp' '$REMOTE_INCOMING'"

remote_log "Building desktop targets on Ubuntu: $PLATFORMS"
desktop_remote_ssh "bash -s -- '$RANTLIST_DESKTOP_BUILD_ROOT' '$RANTLIST_DESKTOP_BUILD_USER' '$REMOTE_INCOMING' '$SOURCE_SHA' '$VERSION' '$BUILD' '$TAG' '$PLATFORMS'" <<'REMOTE'
set -Eeuo pipefail
base="$1"; build_user="$2"; archive="$3"; source_sha="$4"; version="$5"; build="$6"; tag="$7"; platforms="$8"
job="$base/jobs/$tag"
src="$job/source"
art="$base/release-jobs/$tag"
install -d -o "$build_user" -g "$build_user" "$job" "$art"
marker="$job/source.sha256"
if [[ ! -f "$marker" || "$(cat "$marker" 2>/dev/null || true)" != "$source_sha" ]]; then
  rm -rf "$src"
  install -d -o "$build_user" -g "$build_user" "$src"
  runuser -u "$build_user" -- tar -xzf "$archive" -C "$src"
  printf '%s\n' "$source_sha" > "$marker"
  chown "$build_user:$build_user" "$marker"
fi
run_as_builder(){
  runuser -u "$build_user" -- env \
    RANTLIST_DESKTOP_SAFE_BASE="$base" \
    RANTLIST_DESKTOP_RELEASE_ROOT="$art" \
    BUILD_NUMBER_OVERRIDE="$build" \
    bash -lc "cd '$src' && $1"
}
run_as_builder "node scripts/verify_desktop_client.js"
case " $platforms " in *" linux "*) run_as_builder "./scripts/build_linux_release.sh";; esac
case " $platforms " in *" windows "*) run_as_builder "./scripts/build_windows_release.sh";; esac
# Flatten only the exact per-build deliverables into the tag artifact directory.
find "$art" -mindepth 2 -maxdepth 2 -type f \
  \( -name "Rantlist-v${version}-b${build}-linux-*" -o -name "Rantlist-v${version}-b${build}-windows-*" \
     -o -name "Rantlist-v${version}-b${build}-linux-SHA256.txt" -o -name "Rantlist-v${version}-b${build}-windows-SHA256.txt" \
  \) -exec cp -f {} "$art/" \;
# Remove only disposable build/source dependencies inside this dedicated job.
rm -rf "$src/.desktop-build" "$src/desktop/node_modules"
rm -f "$archive"
REMOTE

"$ROOT/scripts/validate_desktop_remote_artifacts.sh" "$VERSION" "$BUILD" "$TAG" "$PLATFORMS"
remote_log "Ubuntu desktop build complete for $TAG: $PLATFORMS"
