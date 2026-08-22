#!/usr/bin/env bash
# Publish an already-built Rantlist macOS release to GitHub using a draft-first flow.
set -Eeuo pipefail
IFS=$'\n\t'
export GIT_PAGER=cat PAGER=cat GH_PAGER=cat GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_TERMINAL_PROMPT=0 GH_PROMPT_DISABLED=1

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
GH_REPO="${GH_REPO:-sylwesterdigital/rantlist-client}"
RELEASE_VERSION="${RELEASE_VERSION:-$(tr -d '[:space:]' < "$ROOT/VERSION.txt" 2>/dev/null || true)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(tr -cd '0-9' < "$ROOT/BUILD_NUMBER.txt" 2>/dev/null || true)}"
RELEASE_TAG="${RELEASE_TAG:-v${RELEASE_VERSION}-b${BUILD_NUMBER}}"
RELEASE_MODE="${GITHUB_RELEASE_MODE:-published}"  # published|prerelease
NOTES_FILE="${RELEASE_NOTES_FILE:-}"

log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
retry_cmd(){ local attempts="$1" delay="$2"; shift 2; local n=1; until "$@"; do local c=$?; (( n >= attempts )) && return "$c"; warn "Command failed ($n/$attempts); retrying in ${delay}s: $*"; sleep "$delay"; n=$((n+1)); done; }

[[ "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid RELEASE_VERSION: $RELEASE_VERSION"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || die "Invalid BUILD_NUMBER: $BUILD_NUMBER"
case "$RELEASE_MODE" in published|prerelease) ;; *) die "GITHUB_RELEASE_MODE must be published or prerelease" ;; esac
command -v gh >/dev/null 2>&1 || die "GitHub CLI is missing."
gh auth status -h github.com >/dev/null 2>&1 || die "GitHub CLI is not authenticated."

DMG="$ROOT/release/Rantlist-v${RELEASE_VERSION}-b${BUILD_NUMBER}-macOS-universal2.dmg"
ZIP="$ROOT/release/Rantlist-v${RELEASE_VERSION}-b${BUILD_NUMBER}-macOS-universal2.zip"
SHA="$ROOT/release/Rantlist-v${RELEASE_VERSION}-b${BUILD_NUMBER}-SHA256.txt"
for f in "$DMG" "$ZIP" "$SHA"; do [[ -s "$f" ]] || die "Missing release artifact: $f"; done
(
  cd "$ROOT/release"
  shasum -a 256 -c "$(basename "$SHA")"
)

if [[ -z "$NOTES_FILE" ]]; then
  NOTES_FILE="$ROOT/release/Rantlist-v${RELEASE_VERSION}-b${BUILD_NUMBER}-RELEASE_NOTES.md"
  SOURCE_REVISION="$(node -e 'const p=require(process.argv[1]); process.stdout.write(String(p.sourceRevision||"unknown"))' "$ROOT/web/client-source.json")"
  cat > "$NOTES_FILE" <<NOTES
# Rantlist ${RELEASE_VERSION} — macOS build ${BUILD_NUMBER}

Native macOS client for **Rantlist**, built from the sanitized public client snapshot corresponding to Rantlist ${RELEASE_VERSION} (${SOURCE_REVISION}).

## Install

1. Download the DMG.
2. Open it.
3. Drag **Rantlist** into **Applications**.
4. Launch Rantlist from Applications.

The application is Developer ID signed and notarized by Apple.

## Assets

- $(basename "$DMG")
- $(basename "$ZIP")
- $(basename "$SHA")

Rantlist: https://rantlist.me

Project page: https://mojoworks.xyz/labs/rantlist/
Source: https://github.com/${GH_REPO}
NOTES
fi
[[ -f "$NOTES_FILE" ]] || die "Release notes file not found: $NOTES_FILE"

if ! git show-ref --tags --verify --quiet "refs/tags/$RELEASE_TAG"; then
  log "Creating annotated Git tag $RELEASE_TAG"
  git tag -a "$RELEASE_TAG" -m "Rantlist ${RELEASE_VERSION} build ${BUILD_NUMBER}"
fi
log "Pushing tag $RELEASE_TAG"
retry_cmd 3 8 git push origin "refs/tags/$RELEASE_TAG"

if gh release view "$RELEASE_TAG" --repo "$GH_REPO" >/dev/null 2>&1; then
  log "GitHub Release $RELEASE_TAG already exists; reusing it"
else
  log "Creating draft GitHub Release $RELEASE_TAG"
  retry_cmd 3 8 gh release create "$RELEASE_TAG" --repo "$GH_REPO" --draft \
    --title "Rantlist ${RELEASE_VERSION} (build ${BUILD_NUMBER})" --notes-file "$NOTES_FILE"
fi

log "Uploading release assets"
for asset in "$DMG" "$ZIP" "$SHA"; do
  retry_cmd 4 10 gh release upload "$RELEASE_TAG" "$asset" --repo "$GH_REPO" --clobber
 done

ASSET_COUNT="$(gh release view "$RELEASE_TAG" --repo "$GH_REPO" --json assets --jq '.assets | length')"
(( ASSET_COUNT >= 3 )) || die "GitHub Release has only $ASSET_COUNT assets after upload."

if [[ "$RELEASE_MODE" == prerelease ]]; then
  log "Publishing prerelease $RELEASE_TAG"
  retry_cmd 3 8 gh release edit "$RELEASE_TAG" --repo "$GH_REPO" --draft=false --prerelease
else
  log "Publishing stable release $RELEASE_TAG"
  retry_cmd 3 8 gh release edit "$RELEASE_TAG" --repo "$GH_REPO" --draft=false
fi

IS_DRAFT="$(gh release view "$RELEASE_TAG" --repo "$GH_REPO" --json isDraft --jq '.isDraft')"
[[ "$IS_DRAFT" == false ]] || die "Release is still a draft."
RELEASE_URL="$(gh release view "$RELEASE_TAG" --repo "$GH_REPO" --json url --jq '.url')"
printf 'GitHub Release published: %s\n' "$RELEASE_URL"
