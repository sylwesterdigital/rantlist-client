#!/usr/bin/env bash
# Publish already-built Rantlist platform artifacts to one GitHub Release.
# Release creation is transaction-aware: a transient GitHub 5xx is never
# followed by a blind duplicate POST. The remote postcondition is checked first.
set -Eeuo pipefail
IFS=$' \n\t'
export GIT_PAGER=cat PAGER=cat GH_PAGER=cat GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true \
  GIT_TERMINAL_PROMPT=0 GH_PROMPT_DISABLED=1 NO_COLOR=1 CLICOLOR=0

ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
GH_REPO="${GH_REPO:-sylwesterdigital/rantlist-client}"
RELEASE_VERSION="${RELEASE_VERSION:-$(tr -d '[:space:]' < "$ROOT/VERSION.txt" 2>/dev/null || true)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(tr -cd '0-9' < "$ROOT/BUILD_NUMBER.txt" 2>/dev/null || true)}"
RELEASE_TAG="${RELEASE_TAG:-v${RELEASE_VERSION}-b${BUILD_NUMBER}}"
RELEASE_MODE="${GITHUB_RELEASE_MODE:-published}"
RELEASE_PLATFORMS="${RELEASE_PLATFORMS:-macos}"
NOTES_FILE="${RELEASE_NOTES_FILE:-}"
GITHUB_TAG_VISIBILITY_ATTEMPTS="${GITHUB_TAG_VISIBILITY_ATTEMPTS:-15}"
GITHUB_TAG_VISIBILITY_DELAY="${GITHUB_TAG_VISIBILITY_DELAY:-2}"
GITHUB_RELEASE_RECOVERY_ATTEMPTS="${GITHUB_RELEASE_RECOVERY_ATTEMPTS:-10}"
GITHUB_RELEASE_RECOVERY_DELAY="${GITHUB_RELEASE_RECOVERY_DELAY:-2}"
GITHUB_RELEASE_ABSENCE_CONFIRMATIONS="${GITHUB_RELEASE_ABSENCE_CONFIRMATIONS:-2}"
GITHUB_CREATE_ATTEMPTS="${GITHUB_CREATE_ATTEMPTS:-3}"
GITHUB_CREATE_RETRY_DELAY="${GITHUB_CREATE_RETRY_DELAY:-4}"

log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
info(){ printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
retry_cmd(){ local attempts="$1" delay="$2"; shift 2; local n=1; until "$@"; do local c=$?; (( n >= attempts )) && return "$c"; warn "Command failed ($n/$attempts); retrying in ${delay}s: $*"; sleep "$delay"; n=$((n+1)); done; }
has_platform(){ case " $RELEASE_PLATFORMS " in *" $1 "*) return 0;; *) return 1;; esac; }

[[ "$RELEASE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid RELEASE_VERSION: $RELEASE_VERSION"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || die "Invalid BUILD_NUMBER: $BUILD_NUMBER"
case "$RELEASE_MODE" in published|prerelease) ;; *) die "GITHUB_RELEASE_MODE must be published or prerelease" ;; esac
for numeric in GITHUB_TAG_VISIBILITY_ATTEMPTS GITHUB_TAG_VISIBILITY_DELAY GITHUB_RELEASE_RECOVERY_ATTEMPTS GITHUB_RELEASE_RECOVERY_DELAY GITHUB_RELEASE_ABSENCE_CONFIRMATIONS GITHUB_CREATE_ATTEMPTS GITHUB_CREATE_RETRY_DELAY; do
  [[ "${!numeric}" =~ ^[0-9]+$ ]] || die "$numeric must be a non-negative integer."
done
(( GITHUB_TAG_VISIBILITY_ATTEMPTS > 0 && GITHUB_RELEASE_RECOVERY_ATTEMPTS > 0 && GITHUB_RELEASE_ABSENCE_CONFIRMATIONS > 0 && GITHUB_CREATE_ATTEMPTS > 0 )) \
  || die "GitHub release attempt counts must be greater than zero."
command -v gh >/dev/null 2>&1 || die "GitHub CLI is missing."
command -v node >/dev/null 2>&1 || die "Node.js is missing."
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
EXPECTED_COMMIT="$(git rev-list -n 1 "$RELEASE_TAG")"
[[ "$EXPECTED_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die "Could not resolve local release tag commit: $RELEASE_TAG"

log "Pushing tag $RELEASE_TAG"
retry_cmd 3 8 git push origin "refs/tags/$RELEASE_TAG"

# Git's receive acknowledgement can precede visibility through GitHub's REST
# release backend. Wait until the exact pushed tag resolves through that API
# before attempting to create a release. This avoids racing release creation.
wait_for_github_tag(){
  local attempts="${1:-12}" delay="${2:-2}" n remote_commit
  for ((n=1; n<=attempts; n++)); do
    remote_commit="$(gh api \
      -H 'Accept: application/vnd.github+json' \
      -H 'X-GitHub-Api-Version: 2022-11-28' \
      "repos/$GH_REPO/commits/$RELEASE_TAG" --jq '.sha' 2>/dev/null || true)"
    if [[ "$remote_commit" == "$EXPECTED_COMMIT" ]]; then
      return 0
    fi
    if [[ -n "$remote_commit" && "$remote_commit" != "$EXPECTED_COMMIT" ]]; then
      die "GitHub resolves $RELEASE_TAG to $remote_commit, expected $EXPECTED_COMMIT."
    fi
    (( n < attempts )) && sleep "$delay"
  done
  return 1
}

RELEASE_QUERY_STATE='unknown'
RELEASE_QUERY_ID=''
RELEASE_QUERY_ERROR=''
query_release_by_tag(){
  local out err status
  out="$(mktemp "${TMPDIR:-/tmp}/rantlist-release-query-out.XXXXXX")"
  err="$(mktemp "${TMPDIR:-/tmp}/rantlist-release-query-err.XXXXXX")"
  set +e
  gh api \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "repos/$GH_REPO/releases/tags/$RELEASE_TAG" --jq '.id' >"$out" 2>"$err"
  status=$?
  set -e

  RELEASE_QUERY_ID=''
  RELEASE_QUERY_ERROR=''
  if (( status == 0 )); then
    RELEASE_QUERY_ID="$(tr -cd '0-9\n' < "$out" | head -n 1)"
    rm -f "$out" "$err"
    if [[ "$RELEASE_QUERY_ID" =~ ^[0-9]+$ ]]; then
      RELEASE_QUERY_STATE='present'
      return 0
    fi
    RELEASE_QUERY_STATE='error'
    RELEASE_QUERY_ERROR='GitHub returned a release response without a numeric id.'
    return 0
  fi

  RELEASE_QUERY_ERROR="$(cat "$err")"
  rm -f "$out" "$err"
  if grep -Eq 'HTTP[[:space:]]+404|Not Found' <<< "$RELEASE_QUERY_ERROR"; then
    RELEASE_QUERY_STATE='absent'
    RELEASE_QUERY_ERROR=''
  else
    RELEASE_QUERY_STATE='error'
  fi
}

# Resolve the postcondition without confusing an API outage with a confirmed
# 404. A retryable create is allowed only after consecutive authenticated 404s.
# Return 0=present, 3=confirmed absent, 4=indeterminate API state.
wait_for_release_resolution(){
  local attempts="${1:-8}" delay="${2:-2}" n absences=0
  for ((n=1; n<=attempts; n++)); do
    query_release_by_tag
    case "$RELEASE_QUERY_STATE" in
      present) return 0 ;;
      absent)
        absences=$((absences + 1))
        if (( absences >= GITHUB_RELEASE_ABSENCE_CONFIRMATIONS )); then
          return 3
        fi
        ;;
      error)
        absences=0
        ;;
    esac
    (( n < attempts )) && sleep "$delay"
  done
  return 4
}

build_release_payload(){
  local output="$1"
  node - "$RELEASE_TAG" "Rantlist ${RELEASE_VERSION} (build ${BUILD_NUMBER})" "$NOTES_FILE" > "$output" <<'NODE'
const fs = require('fs');
const [tag, name, notesFile] = process.argv.slice(2);
const body = fs.readFileSync(notesFile, 'utf8');
process.stdout.write(JSON.stringify({tag_name: tag, name, body, draft: true, prerelease: false}));
NODE
}

create_release_transactionally(){
  local attempt delay payload output status resolution

  wait_for_github_tag "$GITHUB_TAG_VISIBILITY_ATTEMPTS" "$GITHUB_TAG_VISIBILITY_DELAY" \
    || die "Pushed tag $RELEASE_TAG did not become visible through the GitHub API."

  if wait_for_release_resolution "$GITHUB_RELEASE_RECOVERY_ATTEMPTS" "$GITHUB_RELEASE_RECOVERY_DELAY"; then
    log "GitHub Release $RELEASE_TAG already exists; reusing release id $RELEASE_QUERY_ID"
    return 0
  else
    resolution=$?
    if (( resolution != 3 )); then
      [[ -n "$RELEASE_QUERY_ERROR" ]] && printf '%s\n' "$RELEASE_QUERY_ERROR" >&2
      die "Could not establish whether GitHub Release $RELEASE_TAG already exists; refusing a create request while remote state is indeterminate."
    fi
  fi

  payload="$(mktemp "${TMPDIR:-/tmp}/rantlist-release-payload.XXXXXX")"
  build_release_payload "$payload"

  delay="$GITHUB_CREATE_RETRY_DELAY"
  for ((attempt=1; attempt<=GITHUB_CREATE_ATTEMPTS; attempt++)); do
    # Every create POST is preceded by a known-absent release state. A network
    # failure is not treated as absence and therefore can never authorize POST.
    if wait_for_release_resolution "$GITHUB_RELEASE_RECOVERY_ATTEMPTS" "$GITHUB_RELEASE_RECOVERY_DELAY"; then
      log "GitHub Release $RELEASE_TAG is present; reusing release id $RELEASE_QUERY_ID"
      rm -f "$payload"
      return 0
    else
      resolution=$?
      if (( resolution != 3 )); then
        [[ -n "$RELEASE_QUERY_ERROR" ]] && printf '%s\n' "$RELEASE_QUERY_ERROR" >&2
        rm -f "$payload"
        die "GitHub release state became indeterminate before create attempt $attempt; refusing a potentially duplicate POST."
      fi
    fi

    output="$(mktemp "${TMPDIR:-/tmp}/rantlist-release-create.XXXXXX")"
    set +e
    gh api --method POST \
      -H 'Accept: application/vnd.github+json' \
      -H 'X-GitHub-Api-Version: 2022-11-28' \
      "repos/$GH_REPO/releases" --input "$payload" --jq '.id' >"$output" 2>&1
    status=$?
    set -e
    if (( status == 0 )); then
      RELEASE_QUERY_ID="$(tr -cd '0-9\n' < "$output" | head -n 1)"
      rm -f "$output"
      if [[ ! "$RELEASE_QUERY_ID" =~ ^[0-9]+$ ]]; then
        rm -f "$payload"
        die "GitHub created $RELEASE_TAG but did not return a release id."
      fi
      log "Created draft GitHub Release $RELEASE_TAG (id $RELEASE_QUERY_ID)"
      rm -f "$payload"
      return 0
    fi

    # A failed POST is ambiguous: GitHub may have committed the draft before
    # returning 5xx or before the connection broke. Resolve the remote state;
    # only consecutive 404s can authorize another create attempt.
    if wait_for_release_resolution "$GITHUB_RELEASE_RECOVERY_ATTEMPTS" "$GITHUB_RELEASE_RECOVERY_DELAY"; then
      rm -f "$output"
      info "GitHub acknowledged $RELEASE_TAG asynchronously; recovered release id $RELEASE_QUERY_ID without repeating the create request."
      rm -f "$payload"
      return 0
    else
      resolution=$?
    fi

    if (( resolution == 4 )); then
      printf '%s\n' "$(cat "$output")" >&2
      [[ -n "$RELEASE_QUERY_ERROR" ]] && printf '%s\n' "$RELEASE_QUERY_ERROR" >&2
      rm -f "$output" "$payload"
      die "GitHub release state is indeterminate after create attempt $attempt; refusing a potentially duplicate create request."
    fi

    if (( attempt == GITHUB_CREATE_ATTEMPTS )); then
      printf '%s\n' "$(cat "$output")" >&2
      rm -f "$output" "$payload"
      die "GitHub release creation failed after $attempt transaction-safe attempts."
    fi

    rm -f "$output"
    info "GitHub release creation attempt $attempt did not establish a release; authenticated API checks confirmed absence, retrying after ${delay}s."
    sleep "$delay"
    delay=$((delay * 2))
  done
}

create_release_transactionally

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
