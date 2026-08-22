#!/usr/bin/env bash
# Publish already-built Rantlist platform artifacts to one GitHub Release using a draft-first flow.
set -Eeuo pipefail
IFS=$' \n\t'
export GIT_PAGER=cat PAGER=cat GH_PAGER=cat GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_TERMINAL_PROMPT=0 GH_PROMPT_DISABLED=1

ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
GH_REPO="${GH_REPO:-sylwesterdigital/rantlist-client}"
RELEASE_VERSION="${RELEASE_VERSION:-$(tr -d '[:space:]' < "$ROOT/VERSION.txt" 2>/dev/null || true)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(tr -cd '0-9' < "$ROOT/BUILD_NUMBER.txt" 2>/dev/null || true)}"
RELEASE_TAG="${RELEASE_TAG:-v${RELEASE_VERSION}-b${BUILD_NUMBER}}"
RELEASE_MODE="${GITHUB_RELEASE_MODE:-published}"
RELEASE_PLATFORMS="${RELEASE_PLATFORMS:-macos}"
NOTES_FILE="${RELEASE_NOTES_FILE:-}"

log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
retry_cmd(){ local attempts="$1" delay="$2"; shift 2; local n=1; until "$@"; do local c=$?; (( n >= attempts )) && return "$c"; warn "Command failed ($n/$attempts); retrying in ${delay}s: $*"; sleep "$delay"; n=$((n+1)); done; }
has_platform(){ case " $RELEASE_PLATFORMS " in *" $1 "*) return 0;; *) return 1;; esac; }

[[ "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid RELEASE_VERSION: $RELEASE_VERSION"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || die "Invalid BUILD_NUMBER: $BUILD_NUMBER"
case "$RELEASE_MODE" in published|prerelease) ;; *) die "GITHUB_RELEASE_MODE must be published or prerelease" ;; esac
command -v gh >/dev/null 2>&1 || die "GitHub CLI is missing."
gh auth status -h github.com >/dev/null 2>&1 || die "GitHub CLI is not authenticated."

BASE="$ROOT/release/Rantlist-v${RELEASE_VERSION}-b${BUILD_NUMBER}"
assets=()
checksums=()
if has_platform macos; then
  assets+=("${BASE}-macOS-universal2.dmg" "${BASE}-macOS-universal2.zip")
  checksums+=("${BASE}-SHA256.txt")
fi
if has_platform android; then
  assets+=("${BASE}-android.apk" "${BASE}-android.aab")
  checksums+=("${BASE}-android-SHA256.txt")
fi
if has_platform ios; then
  assets+=("${BASE}-iOS.ipa")
  checksums+=("${BASE}-iOS-SHA256.txt")
fi
(( ${#assets[@]} > 0 )) || die "No platform artifacts selected."
for f in "${assets[@]}" "${checksums[@]}"; do [[ -s "$f" ]] || die "Missing release artifact: $f"; done
for sha in "${checksums[@]}"; do (cd "$ROOT/release" && shasum -a 256 -c "$(basename "$sha")"); done

if [[ -z "$NOTES_FILE" ]]; then
  NOTES_FILE="$ROOT/release/Rantlist-v${RELEASE_VERSION}-b${BUILD_NUMBER}-RELEASE_NOTES.md"
  SOURCE_REVISION="$(node -e 'const p=require(process.argv[1]); process.stdout.write(String(p.sourceRevision||"unknown"))' "$ROOT/web/client-source.json")"
  {
    printf '# Rantlist %s — build %s\n\n' "$RELEASE_VERSION" "$BUILD_NUMBER"
    printf 'Native Rantlist clients built from the sanitized public client snapshot corresponding to Rantlist %s (%s).\n\n' "$RELEASE_VERSION" "$SOURCE_REVISION"
    printf '## Platforms\n\n'
    has_platform macos && printf -- '- macOS: signed and notarized universal2 DMG + ZIP\n'
    has_platform android && printf -- '- Android: signed APK + AAB\n'
    has_platform ios && printf -- '- iOS/iPadOS: signed IPA exported for App Store distribution\n'
    printf '\n## Install\n\n'
    has_platform macos && printf 'macOS: open the DMG and drag **Rantlist** into **Applications**.\n\n'
    has_platform android && printf 'Android: install the APK directly, or use the AAB for Google Play publishing.\n\n'
    has_platform ios && printf 'iOS/iPadOS: the IPA is an App Store distribution artifact; normal public installation should use TestFlight or the App Store.\n\n'
    printf 'All Apple desktop artifacts are Developer ID signed/notarized where applicable. Mobile apps use native camera/microphone permission handling for Rantlist calls.\n\n'
    printf '## Assets\n\n'
    for f in "${assets[@]}" "${checksums[@]}"; do printf -- '- %s\n' "$(basename "$f")"; done
    printf '\nRantlist: https://rantlist.me\n\nProject page: https://mojoworks.xyz/labs/rantlist/\n\nSource: https://github.com/%s\n' "$GH_REPO"
  } > "$NOTES_FILE"
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
for asset in "${assets[@]}" "${checksums[@]}"; do
  retry_cmd 4 10 gh release upload "$RELEASE_TAG" "$asset" --repo "$GH_REPO" --clobber
done

remote_assets="$(gh release view "$RELEASE_TAG" --repo "$GH_REPO" --json assets --jq '.assets[].name')"
for asset in "${assets[@]}" "${checksums[@]}"; do
  grep -Fx "$(basename "$asset")" <<< "$remote_assets" >/dev/null || die "GitHub Release is missing uploaded asset: $(basename "$asset")"
done

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
