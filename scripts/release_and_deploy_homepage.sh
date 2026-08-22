#!/usr/bin/env bash
# Resumable Rantlist release: sync -> verify -> selected native builds -> GitHub -> mojoworks homepage.
set -Eeuo pipefail
IFS=$' \n\t'
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
PLATFORM_EXPLICIT=0
REQUESTED_PLATFORMS=""
WORKFLOW_BUILD_SCHEMA="3-multiplatform-logo"

log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok(){ printf '\033[1;32mOK\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

normalize_platforms(){
  local raw="$1" token out=""
  raw="${raw//,/ }"
  for token in $raw; do
    case "$token" in
      all) raw="macos android ios"; out=""; break ;;
      macos|android|ios) ;;
      '') continue ;;
      *) die "Unknown platform: $token (use macos, android, ios, or all)" ;;
    esac
  done
  for token in macos android ios; do
    case " $raw " in *" $token "*) out="${out:+$out }$token";; esac
  done
  [[ -n "$out" ]] || die "No release platform selected."
  printf '%s\n' "$out"
}

append_requested(){
  PLATFORM_EXPLICIT=1
  if [[ "$1" == all ]]; then REQUESTED_PLATFORMS="macos android ios"; return; fi
  REQUESTED_PLATFORMS="${REQUESTED_PLATFORMS:+$REQUESTED_PLATFORMS }$1"
}

has_platform(){ case " $1 " in *" $2 "*) return 0;; *) return 1;; esac; }
add_platform(){ local list="$1" item="$2"; has_platform "$list" "$item" && { printf '%s\n' "$list"; return; }; normalize_platforms "${list:+$list }$item"; }
all_selected_built(){ local p; for p in $PLATFORMS; do has_platform "${BUILT_PLATFORMS:-}" "$p" || return 1; done; return 0; }

usage(){ cat <<'TXT'
Usage:
  ./scripts/release_and_deploy_homepage.sh
  ./scripts/release_and_deploy_homepage.sh --platform macos
  ./scripts/release_and_deploy_homepage.sh --platform android
  ./scripts/release_and_deploy_homepage.sh --platform ios
  ./scripts/release_and_deploy_homepage.sh --platform all
  ./scripts/release_and_deploy_homepage.sh --platform macos,android

Shorthand:
  --macos     release macOS only
  --android   release Android APK + AAB only
  --ios       release iOS IPA only
  --all       release macOS + Android + iOS

Workflow controls:
  --preflight-only
  --status
  --restart
  --prerelease

Default is macOS only for backwards compatibility. No version argument is accepted;
the application version is always read from the verified stage/chat source.
TXT
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) [[ $# -ge 2 ]] || die "--platform requires a value"; append_requested "$2"; shift 2;;
    --macos) append_requested macos; shift;;
    --android) append_requested android; shift;;
    --ios) append_requested ios; shift;;
    --all) append_requested all; shift;;
    --preflight-only) PREVIEW_ONLY=1; shift;;
    --status) SHOW_STATUS=1; shift;;
    --restart) RESTART=1; shift;;
    --prerelease) RELEASE_MODE=prerelease; shift;;
    -h|--help) usage; exit 0;;
    *) die "Unknown option: $1";;
  esac
done

if [[ "$PLATFORM_EXPLICIT" == 1 ]]; then
  REQUESTED_PLATFORMS="$(normalize_platforms "$REQUESTED_PLATFORMS")"
else
  REQUESTED_PLATFORMS="macos"
fi

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
    printf 'PLATFORMS=%q\n' "${PLATFORMS:-macos}"
    printf 'BUILT_PLATFORMS=%q\n' "${BUILT_PLATFORMS:-}"
    printf 'BUILD_SCHEMA=%q\n' "$WORKFLOW_BUILD_SCHEMA"
  } > "$STATE_FILE"
}
load_state(){
  # shellcheck disable=SC1090
  source "$STATE_FILE"
  : "${PHASE:?Invalid release state: PHASE missing}"
  PLATFORMS="${PLATFORMS:-macos}"
  if [[ -z "${BUILT_PLATFORMS+x}" ]]; then
    case "$PHASE" in built|published|complete) BUILT_PLATFORMS="$PLATFORMS";; *) BUILT_PLATFORMS="";; esac
  fi
}

# Resolve effective platform selection before platform-specific preflight.
# Completed state is historical and must never block a new target selection.
# A published state may still have only the homepage phase left; requesting the
# same targets resumes it, while an explicit different target starts a new
# release/build and preserves the published state as the previous release.
if [[ -f "$STATE_FILE" ]]; then
  load_state

  if [[ "$PHASE" == complete ]]; then
    cp "$STATE_FILE" "$LAST_STATE_FILE"
    rm -f "$STATE_FILE"
  elif [[ "$PHASE" == published && "$PLATFORM_EXPLICIT" == 1 ]]; then
    requested_normalized="$(normalize_platforms "$REQUESTED_PLATFORMS")"
    saved_normalized="$(normalize_platforms "$PLATFORMS")"
    if [[ "$requested_normalized" != "$saved_normalized" ]]; then
      log "Previous release $RELEASE_TAG is already published for: $PLATFORMS"
      log "Starting a new release for explicitly requested platforms: $requested_normalized"
      cp "$STATE_FILE" "$LAST_STATE_FILE"
      rm -f "$STATE_FILE"
    fi
  fi
fi

if [[ -f "$STATE_FILE" ]]; then
  load_state
  if [[ "$PLATFORM_EXPLICIT" == 0 ]]; then
    REQUESTED_PLATFORMS="$PLATFORMS"
  elif [[ "$PHASE" != published ]]; then
    requested_normalized="$(normalize_platforms "$REQUESTED_PLATFORMS")"
    saved_normalized="$(normalize_platforms "$PLATFORMS")"
    [[ "$requested_normalized" == "$saved_normalized" ]] \
      || die "Incomplete release state is fixed to platforms: $PLATFORMS. Resume it or use --restart deliberately."
  fi
fi
EFFECTIVE_PLATFORMS="$(normalize_platforms "$REQUESTED_PLATFORMS")"

preflight(){
  local p
  log "Preflight ($EFFECTIVE_PLATFORMS)"
  [[ "$(uname -s)" == Darwin ]] || die "Release must run on macOS."
  for t in git gh node rsync ssh curl shasum; do command -v "$t" >/dev/null 2>&1 || die "Required tool missing: $t"; done
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
    local_head="$(git rev-parse HEAD)"; remote_head="$(git rev-parse "origin/$RELEASE_BRANCH")"; base_head="$(git merge-base HEAD "origin/$RELEASE_BRANCH")"
    if [[ "$local_head" == "$remote_head" ]]; then :
    elif [[ "$base_head" == "$remote_head" ]]; then log "Local $RELEASE_BRANCH is ahead of origin; local commits will be included."
    elif [[ "$base_head" == "$local_head" ]]; then
      [[ -z "$(git status --porcelain)" ]] || die "Local branch is behind origin and has local changes. Synchronize Git first."
      git merge --ff-only "origin/$RELEASE_BRANCH"
    else die "Local $RELEASE_BRANCH has diverged from origin/$RELEASE_BRANCH."; fi
  fi
  node "$ROOT/scripts/source_release.js" "$SOURCE_PROJECT" >/dev/null
  for p in $EFFECTIVE_PLATFORMS; do
    case "$p" in
      macos) "$ROOT/scripts/check_macos_release_credentials.sh";;
      android) "$ROOT/scripts/check_android_release_credentials.sh";;
      ios) "$ROOT/scripts/check_ios_release_credentials.sh";;
    esac
  done
  df -Pk "$ROOT" | awk 'NR==2 { if ($4 < 2097152) { print "ERROR: less than 2GB free disk space" > "/dev/stderr"; exit 1 } }'
  ok "Preflight passed"
}

preflight
[[ "$PREVIEW_ONLY" == 0 ]] || exit 0

if [[ -f "$STATE_FILE" ]]; then
  load_state
  if [[ "$PHASE" == complete ]]; then cp "$STATE_FILE" "$LAST_STATE_FILE"; rm -f "$STATE_FILE"; fi
fi

if [[ -f "$STATE_FILE" ]]; then
  load_state
  if [[ "$PLATFORM_EXPLICIT" == 1 && "$PHASE" != published && "$PHASE" != complete ]]; then
    PLATFORMS="$EFFECTIVE_PLATFORMS"
  fi
  log "Resuming release $RELEASE_TAG from phase: $PHASE; platforms: $PLATFORMS"
  [[ -n "${SOURCE_VERSION:-}" && -n "${PLANNED_BUILD:-}" && -n "${RELEASE_TAG:-}" ]] || die "Incomplete state file; use --restart."
  if [[ "$PHASE" == published && -n "${RELEASE_COMMIT:-}" ]]; then
    git merge-base --is-ancestor "$RELEASE_COMMIT" HEAD || die "Current Git history diverged from published release commit; refusing homepage resume."
  elif [[ "$PHASE" != published ]]; then
    [[ -f VERSION.txt && "$(tr -d '[:space:]' < VERSION.txt)" == "$SOURCE_VERSION" ]] || die "Release source changed since workflow started; use --restart deliberately."
  fi
  if [[ "$PHASE" != published && "$PHASE" != complete && "${BUILD_SCHEMA:-}" != "$WORKFLOW_BUILD_SCHEMA" ]]; then
    warn "Saved artifacts predate the current multi-platform/logo build rules; rebuilding selected targets with the same planned build number."
    PHASE="planned"; RELEASE_COMMIT=""; BUILT_PLATFORMS=""; write_state planned
  elif [[ "$PHASE" == built && ! all_selected_built ]]; then
    PHASE="planned"; write_state planned
  else
    write_state "$PHASE"
  fi
else
  log "Synchronizing verified Rantlist client core from $SOURCE_PROJECT"
  SOURCE_PROJECT="$SOURCE_PROJECT" "$ROOT/scripts/sync_from_stage.sh"
  "$ROOT/scripts/verify_client_repo.sh"
  node "$ROOT/scripts/security_scan.js" "$ROOT"
  SOURCE_VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION.txt")"
  SOURCE_REVISION="$(node -e 'const p=require(process.argv[1]);process.stdout.write(String(p.sourceRevision||"unknown"))' "$ROOT/web/client-source.json")"
  LOCAL_BUILD="0"
  if [[ -f "$ROOT/BUILD_NUMBER.txt" ]]; then
    LOCAL_BUILD="$(tr -cd '0-9' < "$ROOT/BUILD_NUMBER.txt")"; LOCAL_BUILD="${LOCAL_BUILD:-0}"
  fi
  TAG_BUILD="$(git tag -l "v${SOURCE_VERSION}-b*" | sed -nE "s/^v${SOURCE_VERSION//./\.}-b([0-9]+)$/\1/p" | sort -n | tail -n 1)"
  TAG_BUILD="${TAG_BUILD:-0}"
  GH_BUILD="$(gh release list --repo "$GH_REPO" --limit 100 --json tagName --jq '.[].tagName' 2>/dev/null | sed -nE "s/^v${SOURCE_VERSION//./\.}-b([0-9]+)$/\1/p" | sort -n | tail -n 1)"
  GH_BUILD="${GH_BUILD:-0}"
  PREVIOUS_BUILD="$LOCAL_BUILD"
  (( TAG_BUILD > PREVIOUS_BUILD )) && PREVIOUS_BUILD="$TAG_BUILD"
  (( GH_BUILD > PREVIOUS_BUILD )) && PREVIOUS_BUILD="$GH_BUILD"
  PLANNED_BUILD="$((10#$PREVIOUS_BUILD + 1))"
  RELEASE_TAG="v${SOURCE_VERSION}-b${PLANNED_BUILD}"
  RELEASE_COMMIT=""; PLATFORMS="$EFFECTIVE_PLATFORMS"; BUILT_PLATFORMS=""; PHASE="planned"
  if git show-ref --tags --verify --quiet "refs/tags/$RELEASE_TAG" || git ls-remote --exit-code --tags origin "refs/tags/$RELEASE_TAG" >/dev/null 2>&1; then die "Tag already exists: $RELEASE_TAG"; fi
  if gh release view "$RELEASE_TAG" --repo "$GH_REPO" >/dev/null 2>&1; then die "GitHub release already exists: $RELEASE_TAG"; fi
  write_state planned
  log "Planned release: Rantlist $SOURCE_VERSION build $PLANNED_BUILD ($RELEASE_TAG); platforms: $PLATFORMS"
fi

load_state

validate_platform_artifacts(){
  local p="$1" base="$ROOT/release/Rantlist-v${SOURCE_VERSION}-b${PLANNED_BUILD}"
  case "$p" in
    macos)
      local sha="${base}-SHA256.txt"
      for f in "${base}-macOS-universal2.dmg" "${base}-macOS-universal2.zip" "$sha"; do [[ -s "$f" ]] || return 1; done
      (cd "$ROOT/release" && shasum -a 256 -c "$(basename "$sha")") >/dev/null
      ;;
    android)
      local sha="${base}-android-SHA256.txt"
      for f in "${base}-android.apk" "${base}-android.aab" "$sha"; do [[ -s "$f" ]] || return 1; done
      (cd "$ROOT/release" && shasum -a 256 -c "$(basename "$sha")") >/dev/null
      ;;
    ios)
      local sha="${base}-iOS-SHA256.txt"
      for f in "${base}-iOS.ipa" "$sha"; do [[ -s "$f" ]] || return 1; done
      (cd "$ROOT/release" && shasum -a 256 -c "$(basename "$sha")") >/dev/null
      ;;
  esac
}

if [[ "$PHASE" == planned ]]; then
  for platform in $PLATFORMS; do
    if has_platform "$BUILT_PLATFORMS" "$platform" && validate_platform_artifacts "$platform"; then
      log "Reusing verified $platform artifacts for $RELEASE_TAG"
      continue
    fi
    case "$platform" in
      macos)
        log "Building signed/notarized macOS release"
        BUILD_NUMBER_OVERRIDE="$PLANNED_BUILD" PERSIST_BUILD_NUMBER=0 "$ROOT/scripts/release_signed.sh"
        ;;
      android)
        log "Building signed Android APK + AAB"
        BUILD_NUMBER_OVERRIDE="$PLANNED_BUILD" PERSIST_BUILD_NUMBER=0 "$ROOT/scripts/build_android_release.sh"
        ;;
      ios)
        log "Building signed iOS IPA"
        BUILD_NUMBER_OVERRIDE="$PLANNED_BUILD" PERSIST_BUILD_NUMBER=0 "$ROOT/scripts/build_ios_release.sh"
        ;;
    esac
    validate_platform_artifacts "$platform" || die "$platform build completed without the expected verified artifacts."
    BUILT_PLATFORMS="$(add_platform "$BUILT_PLATFORMS" "$platform")"
    write_state planned
  done
  all_selected_built || die "Not all selected platforms were built: selected=$PLATFORMS built=$BUILT_PLATFORMS"
  printf '%s\n' "$PLANNED_BUILD" > "$ROOT/BUILD_NUMBER.txt"
  PHASE="built"; write_state built
fi

load_state
if [[ "$PHASE" == built ]]; then
  for platform in $PLATFORMS; do validate_platform_artifacts "$platform" || die "Saved built phase is missing/invalid $platform artifacts."; done
  log "Committing and pushing public client release source"
  git add -- .gitignore README.md SECURITY.md RELEASE.md assets macos mobile scripts homepage web VERSION.txt BUILD_NUMBER.txt
  git diff --cached --check -- . ':(exclude)web/**'
  if ! git diff --cached --quiet; then git commit -m "Release Rantlist ${SOURCE_VERSION} build ${PLANNED_BUILD} (${PLATFORMS// /, })"; fi
  RELEASE_COMMIT="$(git rev-parse HEAD)"
  git push origin "$RELEASE_BRANCH"

  log "Publishing GitHub release $RELEASE_TAG"
  RELEASE_VERSION="$SOURCE_VERSION" BUILD_NUMBER="$PLANNED_BUILD" RELEASE_TAG="$RELEASE_TAG" \
    RELEASE_PLATFORMS="$PLATFORMS" RELEASE_MODE="$RELEASE_MODE" GITHUB_RELEASE_MODE="$RELEASE_MODE" \
    "$ROOT/scripts/publish_github_release.sh"
  PHASE="published"; write_state published
fi

load_state
if [[ "$PHASE" == published ]]; then
  log "Deploying Rantlist homepage from exact published tag $RELEASE_TAG"
  "$ROOT/scripts/deploy_homepage.sh" --release-tag "$RELEASE_TAG" --release-channel "$([[ "$RELEASE_MODE" == prerelease ]] && echo prerelease || echo stable)"
  PHASE="complete"; write_state complete
fi

load_state
if [[ "$PHASE" == complete ]]; then
  cp "$STATE_FILE" "$LAST_STATE_FILE"
  ok "Release complete: $RELEASE_TAG ($PLATFORMS)"
  echo "GitHub: https://github.com/$GH_REPO/releases/tag/$RELEASE_TAG"
  echo "Homepage: https://mojoworks.xyz/labs/rantlist/"
  rm -f "$STATE_FILE"
fi
