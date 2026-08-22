#!/usr/bin/env bash
# Resumable Rantlist release: sync -> verify -> signed/notarized macOS build -> GitHub -> mojoworks homepage.
set -Eeuo pipefail
IFS=$'\n\t'
export GIT_PAGER=cat PAGER=cat GH_PAGER=cat GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_MERGE_AUTOEDIT=no GIT_TERMINAL_PROMPT=0 GH_PROMPT_DISABLED=1 LESS='-FRX'

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SOURCE_PROJECT="${SOURCE_PROJECT:-/Users/smielniczuk/Documents/works/stage/chat}"
GH_REPO="${GH_REPO:-sylwesterdigital/rantlist-client}"
RELEASE_BRANCH="${RELEASE_BRANCH:-main}"
STATE_DIR="$ROOT/release"
STATE_FILE="$STATE_DIR/.release-workflow-state.env"
LAST_STATE_FILE="$STATE_DIR/.last-release-workflow-state.env"
PREVIEW_ONLY=0
SHOW_STATUS=0
RESTART=0
RELEASE_MODE="published"

log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok(){ printf '\033[1;32mOK\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
usage(){ cat <<'TXT'
Usage:
  ./scripts/release_and_deploy_homepage.sh
  ./scripts/release_and_deploy_homepage.sh --preflight-only
  ./scripts/release_and_deploy_homepage.sh --status
  ./scripts/release_and_deploy_homepage.sh --restart
  ./scripts/release_and_deploy_homepage.sh --prerelease

Normal release requires no version argument. The application version is read from stage/chat.
TXT
}
while [[ $# -gt 0 ]]; do case "$1" in
  --preflight-only) PREVIEW_ONLY=1; shift;;
  --status) SHOW_STATUS=1; shift;;
  --restart) RESTART=1; shift;;
  --prerelease) RELEASE_MODE=prerelease; shift;;
  -h|--help) usage; exit 0;;
  *) die "Unknown option: $1";;
esac; done

mkdir -p "$STATE_DIR"
if [[ "$SHOW_STATUS" == 1 ]]; then
  if [[ -f "$STATE_FILE" ]]; then cat "$STATE_FILE"; elif [[ -f "$LAST_STATE_FILE" ]]; then echo "No active release. Last completed state:"; cat "$LAST_STATE_FILE"; else echo "No release workflow state."; fi
  exit 0
fi
if [[ "$RESTART" == 1 ]]; then
  rm -f "$STATE_FILE"
  log "Incomplete release state cleared."
fi

write_state(){
  local phase="$1"
  {
    printf 'PHASE=%q\n' "$phase"
    printf 'SOURCE_VERSION=%q\n' "${SOURCE_VERSION:-}"
    printf 'SOURCE_REVISION=%q\n' "${SOURCE_REVISION:-}"
    printf 'PLANNED_BUILD=%q\n' "${PLANNED_BUILD:-}"
    printf 'RELEASE_TAG=%q\n' "${RELEASE_TAG:-}"
    printf 'RELEASE_MODE=%q\n' "${RELEASE_MODE:-published}"
    printf 'RELEASE_COMMIT=%q\n' "${RELEASE_COMMIT:-}"
  } > "$STATE_FILE"
}
load_state(){
  # shellcheck disable=SC1090
  source "$STATE_FILE"
  : "${PHASE:?Invalid release state: PHASE missing}"
}

preflight(){
  log "Preflight"
  [[ "$(uname -s)" == Darwin ]] || die "Release must run on macOS."
  for t in git gh node rsync ssh curl security xcrun codesign swiftc hdiutil ditto lipo shasum; do command -v "$t" >/dev/null 2>&1 || die "Required tool missing: $t"; done
  [[ -d "$ROOT/.git" ]] || die "$ROOT is not a Git repository."
  [[ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)" == "$RELEASE_BRANCH" ]] || die "Release must run on $RELEASE_BRANCH."
  [[ -z "$(git diff --name-only --diff-filter=U)" ]] || die "Resolve Git conflicts first."
  gh auth status -h github.com >/dev/null 2>&1 || die "GitHub CLI is not authenticated."
  [[ "$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)" == "$GH_REPO" ]] || die "This checkout is not $GH_REPO."
  git remote get-url origin >/dev/null 2>&1 || die "origin is missing."
  git ls-remote origin HEAD >/dev/null 2>&1 || die "Git transport to origin failed."
  git fetch --tags origin "$RELEASE_BRANCH"
  if git show-ref --verify --quiet "refs/remotes/origin/$RELEASE_BRANCH"; then
    local local_head remote_head base_head
    local_head="$(git rev-parse HEAD)"
    remote_head="$(git rev-parse "origin/$RELEASE_BRANCH")"
    base_head="$(git merge-base HEAD "origin/$RELEASE_BRANCH")"
    if [[ "$local_head" == "$remote_head" ]]; then
      :
    elif [[ "$base_head" == "$remote_head" ]]; then
      log "Local $RELEASE_BRANCH is ahead of origin; local commits will be included."
    elif [[ "$base_head" == "$local_head" ]]; then
      [[ -z "$(git status --porcelain)" ]] || die "Local branch is behind origin and has local changes. Synchronize Git first."
      git merge --ff-only "origin/$RELEASE_BRANCH"
    else
      die "Local $RELEASE_BRANCH has diverged from origin/$RELEASE_BRANCH."
    fi
  fi
  node "$ROOT/scripts/source_release.js" "$SOURCE_PROJECT" >/dev/null
  "$ROOT/scripts/check_macos_release_credentials.sh"
  df -Pk "$ROOT" | awk 'NR==2 { if ($4 < 1048576) { print "ERROR: less than 1GB free disk space" > "/dev/stderr"; exit 1 } }'
  ok "Preflight passed"
}

preflight
[[ "$PREVIEW_ONLY" == 0 ]] || exit 0

if [[ -f "$STATE_FILE" ]]; then
  load_state
  if [[ "$PHASE" == complete ]]; then
    cp "$STATE_FILE" "$LAST_STATE_FILE"
    rm -f "$STATE_FILE"
  fi
fi

if [[ -f "$STATE_FILE" ]]; then
  load_state
  log "Resuming release $RELEASE_TAG from phase: $PHASE"
  [[ -n "${SOURCE_VERSION:-}" && -n "${PLANNED_BUILD:-}" && -n "${RELEASE_TAG:-}" ]] || die "Incomplete state file; use --restart."
  if [[ "$PHASE" == published && -n "${RELEASE_COMMIT:-}" ]]; then
    git merge-base --is-ancestor "$RELEASE_COMMIT" HEAD || die "Current Git history diverged from published release commit; refusing homepage resume."
  elif [[ "$PHASE" != published ]]; then
    [[ -f VERSION.txt && "$(tr -d '[:space:]' < VERSION.txt)" == "$SOURCE_VERSION" ]] || die "Release source changed since workflow started; use --restart deliberately."
  fi
else
  log "Synchronizing verified Rantlist client core from $SOURCE_PROJECT"
  SOURCE_PROJECT="$SOURCE_PROJECT" "$ROOT/scripts/sync_from_stage.sh"
  "$ROOT/scripts/verify_client_repo.sh"
  node "$ROOT/scripts/security_scan.js" "$ROOT"
  SOURCE_VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION.txt")"
  SOURCE_REVISION="$(node -e 'const p=require(process.argv[1]);process.stdout.write(String(p.sourceRevision||"unknown"))' "$ROOT/web/client-source.json")"
  [[ -f "$ROOT/BUILD_NUMBER.txt" ]] || printf '0\n' > "$ROOT/BUILD_NUMBER.txt"
  PREVIOUS_BUILD="$(tr -cd '0-9' < "$ROOT/BUILD_NUMBER.txt")"; PREVIOUS_BUILD="${PREVIOUS_BUILD:-0}"
  PLANNED_BUILD="$((10#$PREVIOUS_BUILD + 1))"
  RELEASE_TAG="v${SOURCE_VERSION}-b${PLANNED_BUILD}"
  RELEASE_COMMIT=""
  PHASE="planned"
  if git show-ref --tags --verify --quiet "refs/tags/$RELEASE_TAG" || git ls-remote --exit-code --tags origin "refs/tags/$RELEASE_TAG" >/dev/null 2>&1; then die "Tag already exists: $RELEASE_TAG"; fi
  if gh release view "$RELEASE_TAG" --repo "$GH_REPO" >/dev/null 2>&1; then die "GitHub release already exists: $RELEASE_TAG"; fi
  write_state planned
  log "Planned release: Rantlist $SOURCE_VERSION build $PLANNED_BUILD ($RELEASE_TAG)"
fi

# shellcheck disable=SC1090
source "$STATE_FILE"
DMG="$ROOT/release/Rantlist-v${SOURCE_VERSION}-b${PLANNED_BUILD}-macOS-universal2.dmg"
ZIP="$ROOT/release/Rantlist-v${SOURCE_VERSION}-b${PLANNED_BUILD}-macOS-universal2.zip"
SHA="$ROOT/release/Rantlist-v${SOURCE_VERSION}-b${PLANNED_BUILD}-SHA256.txt"

if [[ "$PHASE" == planned ]]; then
  log "Building signed/notarized macOS release"
  BUILD_NUMBER_OVERRIDE="$PLANNED_BUILD" PERSIST_BUILD_NUMBER=0 "$ROOT/scripts/release_signed.sh"
  for f in "$DMG" "$ZIP" "$SHA"; do [[ -s "$f" ]] || die "Build completed without expected artifact: $f"; done
  ( cd "$ROOT/release" && shasum -a 256 -c "$(basename "$SHA")" )
  printf '%s\n' "$PLANNED_BUILD" > "$ROOT/BUILD_NUMBER.txt"
  PHASE="built"; write_state built
fi

# Reload in case phase changed.
load_state
if [[ "$PHASE" == built ]]; then
  for f in "$DMG" "$ZIP" "$SHA"; do [[ -s "$f" ]] || die "Saved built phase is missing artifact: $f"; done
  ( cd "$ROOT/release" && shasum -a 256 -c "$(basename "$SHA")" )

  log "Committing and pushing public client release source"
  git add -- .gitignore README.md SECURITY.md RELEASE.md macos scripts homepage web VERSION.txt BUILD_NUMBER.txt
  # The synchronized web/ tree mirrors production client assets byte-for-byte after
  # sanitization. Third-party SVGs and legacy HTML can contain harmless trailing
  # whitespace, so do not make those formatting details a release blocker.
  # Continue checking repository-owned release/build code for whitespace errors.
  git diff --cached --check -- . ':(exclude)web/**'
  if ! git diff --cached --quiet; then
    git commit -m "Release Rantlist ${SOURCE_VERSION} build ${PLANNED_BUILD}"
  fi
  RELEASE_COMMIT="$(git rev-parse HEAD)"
  git push origin "$RELEASE_BRANCH"

  log "Publishing GitHub release $RELEASE_TAG"
  RELEASE_VERSION="$SOURCE_VERSION" BUILD_NUMBER="$PLANNED_BUILD" RELEASE_TAG="$RELEASE_TAG" \
    RELEASE_MODE="$RELEASE_MODE" GITHUB_RELEASE_MODE="$RELEASE_MODE" \
    "$ROOT/scripts/publish_github_release.sh"
  PHASE="published"; write_state published
fi

load_state
if [[ "$PHASE" == published ]]; then
  log "Deploying Rantlist homepage from exact published tag $RELEASE_TAG"
  "$ROOT/scripts/deploy_homepage.sh" --release-tag "$RELEASE_TAG" --release-channel "$([[ "$RELEASE_MODE" == prerelease ]] && echo prerelease || echo stable)" --release-arch universal2
  PHASE="complete"; write_state complete
fi

load_state
if [[ "$PHASE" == complete ]]; then
  cp "$STATE_FILE" "$LAST_STATE_FILE"
  ok "Release complete: $RELEASE_TAG"
  echo "GitHub: https://github.com/$GH_REPO/releases/tag/$RELEASE_TAG"
  echo "Homepage: https://mojoworks.xyz/labs/rantlist/"
fi
