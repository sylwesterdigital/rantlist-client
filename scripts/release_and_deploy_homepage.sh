#!/usr/bin/env bash
# Resumable Rantlist release: sync -> verify -> selected native builds -> GitHub -> mojoworks homepage.
set -Eeuo pipefail
IFS=$' \n\t'
export GIT_PAGER=cat PAGER=cat GH_PAGER=cat GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_MERGE_AUTOEDIT=no GIT_TERMINAL_PROMPT=0 GH_PROMPT_DISABLED=1 NO_COLOR=1 CLICOLOR=0 LESS='-FRX'

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SOURCE_PROJECT="${SOURCE_PROJECT:-/Users/smielniczuk/Documents/works/stage/chat}"
GH_REPO="${GH_REPO:-sylwesterdigital/rantlist-client}"
RELEASE_BRANCH="${RELEASE_BRANCH:-main}"
STATE_DIR="$ROOT/release"
STATE_FILE="$STATE_DIR/.release-workflow-state.env"
LAST_STATE_FILE="$STATE_DIR/.last-release-workflow-state.env"
OPERATOR_CONTENT="$ROOT/homepage/content.json"
OPERATOR_CONTENT_BACKUP=""

protect_operator_content(){
  [[ -f "$OPERATOR_CONTENT" ]] || return 0
  OPERATOR_CONTENT_BACKUP="$(mktemp /tmp/rantlist-homepage-content.XXXXXX)"
  cp "$OPERATOR_CONTENT" "$OPERATOR_CONTENT_BACKUP"
}
restore_operator_content(){
  [[ -n "$OPERATOR_CONTENT_BACKUP" && -f "$OPERATOR_CONTENT_BACKUP" ]] || return 0
  mkdir -p "$(dirname "$OPERATOR_CONTENT")"
  cp "$OPERATOR_CONTENT_BACKUP" "$OPERATOR_CONTENT"
}
cleanup_operator_content(){
  restore_operator_content || true
  [[ -z "$OPERATOR_CONTENT_BACKUP" ]] || rm -f "$OPERATOR_CONTENT_BACKUP"
}
protect_operator_content
trap cleanup_operator_content EXIT
PREVIEW_ONLY=0
SHOW_STATUS=0
RESTART=0
RELEASE_MODE="published"
PLATFORM_EXPLICIT=0
REQUESTED_PLATFORMS=""
WORKFLOW_BUILD_SCHEMA="5-six-platform-quest"
RANTLIST_INCLUDE_DESKTOP_WITH_GENERAL_RELEASE="${RANTLIST_INCLUDE_DESKTOP_WITH_GENERAL_RELEASE:-1}"

log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok(){ printf '\033[1;32mOK\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
storage_red(){ printf '\033[1;31m%s\033[0m\n' "$*" >&2; }
human_kb(){ awk -v kb="$1" 'BEGIN { if (kb >= 1048576) printf "%.2f GiB", kb/1048576; else printf "%.0f MiB", kb/1024 }'; }

normalize_platforms(){
  local raw="$1" token out=""
  raw="${raw//,/ }"
  for token in $raw; do
    case "$token" in
      all) raw="macos android quest ios windows linux"; out=""; break ;;
      macos|android|quest|ios|windows|linux) ;;
      '') continue ;;
      *) die "Unknown platform: $token (use macos, android, quest, ios, windows, linux, or all)" ;;
    esac
  done
  # Backwards-compatible watcher integration: the historical general release set
  # macos+android+ios now gains the two desktop companion targets automatically.
  # Set RANTLIST_INCLUDE_DESKTOP_WITH_GENERAL_RELEASE=0 only for an intentional
  # legacy three-platform release.
  if [[ "$RANTLIST_INCLUDE_DESKTOP_WITH_GENERAL_RELEASE" == 1 ]]; then
    case " $raw " in *" macos "*) has_macos=1;; *) has_macos=0;; esac
    case " $raw " in *" android "*) has_android=1;; *) has_android=0;; esac
    case " $raw " in *" ios "*) has_ios=1;; *) has_ios=0;; esac
    if [[ "$has_macos$has_android$has_ios" == 111 ]]; then
      raw="$raw quest windows linux"
    fi
  fi
  for token in macos android quest ios windows linux; do
    case " $raw " in *" $token "*) out="${out:+$out }$token";; esac
  done
  [[ -n "$out" ]] || die "No release platform selected."
  printf '%s\n' "$out"
}

append_requested(){
  PLATFORM_EXPLICIT=1
  if [[ "$1" == all ]]; then REQUESTED_PLATFORMS="macos android quest ios windows linux"; return; fi
  REQUESTED_PLATFORMS="${REQUESTED_PLATFORMS:+$REQUESTED_PLATFORMS }$1"
}

has_platform(){ case " $1 " in *" $2 "*) return 0;; *) return 1;; esac; }
add_platform(){ local list="$1" item="$2"; has_platform "$list" "$item" && { printf '%s\n' "$list"; return; }; printf '%s\n' "${list:+$list }$item"; }
all_selected_built(){ local p; for p in $PLATFORMS; do has_platform "${BUILT_PLATFORMS:-}" "$p" || return 1; done; return 0; }

local_free_kb(){
  df -Pk "$ROOT" | awk 'NR==2 { print $4 }'
}

cleanup_local_build_space(){
  # Only generated files inside this checkout. Never touches system caches,
  # user documents, SDKs, Keychain data or background/system configuration.
  local p
  for p in \
    "$ROOT/.macos-build" \
    "$ROOT/.ios-build" \
    "$ROOT/mobile/android/app/build" \
    "$ROOT/mobile/android/.gradle" \
    "$ROOT/mobile/quest/app/build" \
    "$ROOT/mobile/quest/.gradle"; do
    [[ ! -e "$p" ]] || rm -rf -- "$p"
  done
}

cleanup_after_local_platform(){
  case "$1" in
    android) rm -rf -- "$ROOT/mobile/android/app/build" "$ROOT/mobile/android/.gradle";;
    quest) rm -rf -- "$ROOT/mobile/quest/app/build" "$ROOT/mobile/quest/.gradle";;
    ios) rm -rf -- "$ROOT/.ios-build";;
    macos) rm -rf -- "$ROOT/.macos-build";;
  esac
}

check_local_release_space(){
  local free_kb free_human
  log "Checking local release storage: $ROOT"
  free_kb="$(local_free_kb)"
  [[ "$free_kb" =~ ^[0-9]+$ ]] || die "Could not determine free disk space for $ROOT."
  free_human="$(human_kb "$free_kb")"
  printf '    Available: %s (%s KB)\n' "$free_human" "$free_kb"
  printf '    Recommended before release: 2.00 GiB\n'
  printf '    Absolute minimum: 512 MiB\n'
  if (( free_kb < 2*1024*1024 )); then
    storage_red "============================================================"
    storage_red "LOW DISK SPACE: only $free_human free on the local release volume."
    storage_red "Attempting safe cleanup of Rantlist project-local build files only."
    storage_red "============================================================"
    cleanup_local_build_space
    free_kb="$(local_free_kb)"
    [[ "$free_kb" =~ ^[0-9]+$ ]] || die "Could not determine free disk space after cleanup."
    free_human="$(human_kb "$free_kb")"
    storage_red "After cleanup: $free_human free."
  fi
  if (( free_kb < 512*1024 )); then
    storage_red "============================================================"
    storage_red "RELEASE STOPPED — NOT ENOUGH STORAGE"
    storage_red "Location: $ROOT"
    storage_red "Available: $free_human"
    storage_red "Required minimum: 512 MiB"
    storage_red "Recommended: 2.00 GiB or more"
    storage_red "Free disk space, then leave the watcher running; it will retry when a newer package appears."
    storage_red "============================================================"
    exit 1
  fi
  if (( free_kb < 2*1024*1024 )); then
    storage_red "LOW DISK SPACE WARNING: release is continuing with only $free_human free."
  else
    ok "Local storage: $free_human free"
  fi
}

usage(){ cat <<'TXT'
Usage:
  ./scripts/release_and_deploy_homepage.sh
  ./scripts/release_and_deploy_homepage.sh --platform macos
  ./scripts/release_and_deploy_homepage.sh --platform android
  ./scripts/release_and_deploy_homepage.sh --platform quest
  ./scripts/release_and_deploy_homepage.sh --platform ios
  ./scripts/release_and_deploy_homepage.sh --platform windows
  ./scripts/release_and_deploy_homepage.sh --platform linux
  ./scripts/release_and_deploy_homepage.sh --platform all
  ./scripts/release_and_deploy_homepage.sh --platform macos,android

Shorthand:
  --macos     release macOS only
  --android   release Android APK + AAB only
  --quest     release Meta Quest APK + AAB only
  --ios       release iOS IPA only
  --windows   release Windows x64 via Ubuntu build worker
  --linux     release Linux x86_64 via Ubuntu build worker
  --all       release macOS + Android + Quest + iOS + Windows + Linux

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
    --quest) append_requested quest; shift;;
    --ios) append_requested ios; shift;;
    --windows) append_requested windows; shift;;
    --linux) append_requested linux; shift;;
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
  for t in git gh node rsync ssh scp tar curl shasum; do command -v "$t" >/dev/null 2>&1 || die "Required tool missing: $t"; done
  [[ -d "$ROOT/.git" ]] || die "$ROOT is not a Git repository."
  [[ "$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)" == "$RELEASE_BRANCH" ]] || die "Release must run on $RELEASE_BRANCH."
  [[ -z "$(git diff --name-only --diff-filter=U)" ]] || die "Resolve Git conflicts first."
  if ! git diff --check -- . ':(exclude)web/**' ':(exclude)homepage/content.json'; then
    die "Fix source whitespace errors before building the release."
  fi
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
      [[ -z "$(git status --porcelain -- . ':(exclude)homepage/content.json')" ]] || die "Local branch is behind origin and has release-source changes. Synchronize Git first."
      git merge --ff-only "origin/$RELEASE_BRANCH"
      restore_operator_content
    else die "Local $RELEASE_BRANCH has diverged from origin/$RELEASE_BRANCH."; fi
  fi
  node "$ROOT/scripts/source_release.js" "$SOURCE_PROJECT" >/dev/null
  local needs_desktop=0
  for p in $EFFECTIVE_PLATFORMS; do
    case "$p" in
      macos) "$ROOT/scripts/check_macos_release_credentials.sh";;
      android|quest) "$ROOT/scripts/check_android_release_credentials.sh";;
      ios) "$ROOT/scripts/check_ios_release_credentials.sh";;
      windows|linux) needs_desktop=1;;
    esac
  done
  check_local_release_space
  [[ "$needs_desktop" == 0 ]] || "$ROOT/scripts/check_desktop_build_worker.sh"
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
  restore_operator_content
  node "$ROOT/scripts/sync_homepage_development.js" "$SOURCE_PROJECT"
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
    quest)
      local sha="${base}-quest-SHA256.txt"
      for f in "${base}-quest.apk" "${base}-quest.aab" "$sha"; do [[ -s "$f" ]] || return 1; done
      (cd "$ROOT/release" && shasum -a 256 -c "$(basename "$sha")") >/dev/null
      ;;
    ios)
      local sha="${base}-iOS-SHA256.txt"
      for f in "${base}-iOS.ipa" "$sha"; do [[ -s "$f" ]] || return 1; done
      (cd "$ROOT/release" && shasum -a 256 -c "$(basename "$sha")") >/dev/null
      ;;
    linux|windows)
      "$ROOT/scripts/validate_desktop_remote_artifacts.sh" "$SOURCE_VERSION" "$PLANNED_BUILD" "$RELEASE_TAG" "$p" >/dev/null
      ;;
  esac
}

if [[ "$PHASE" == planned ]]; then
  # Apple/Android targets build locally on the Mac exactly as before.
  for platform in android quest ios macos; do
    has_platform "$PLATFORMS" "$platform" || continue
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
      quest)
        log "Building signed Meta Quest APK + AAB"
        BUILD_NUMBER_OVERRIDE="$PLANNED_BUILD" PERSIST_BUILD_NUMBER=0 "$ROOT/scripts/build_quest_release.sh"
        ;;
      ios)
        log "Building signed iOS IPA"
        BUILD_NUMBER_OVERRIDE="$PLANNED_BUILD" PERSIST_BUILD_NUMBER=0 "$ROOT/scripts/build_ios_release.sh"
        ;;
    esac
    validate_platform_artifacts "$platform" || die "$platform build completed without the expected verified artifacts."
    BUILT_PLATFORMS="$(add_platform "$BUILT_PLATFORMS" "$platform")"
    write_state planned
    cleanup_after_local_platform "$platform"
  done

  # Windows/Linux are one remote build-worker transaction. Nothing is copied
  # into Downloads; artifacts remain on Ubuntu until GitHub upload staging.
  desktop_targets=""
  for platform in windows linux; do
    has_platform "$PLATFORMS" "$platform" || continue
    if has_platform "$BUILT_PLATFORMS" "$platform" && validate_platform_artifacts "$platform"; then
      log "Reusing verified remote $platform artifacts for $RELEASE_TAG"
    else
      desktop_targets="${desktop_targets:+$desktop_targets }$platform"
    fi
  done
  if [[ -n "$desktop_targets" ]]; then
    log "Building remote desktop releases on Ubuntu: $desktop_targets"
    "$ROOT/scripts/build_desktop_remote.sh" "$SOURCE_VERSION" "$PLANNED_BUILD" "$RELEASE_TAG" "$desktop_targets"
    for platform in $desktop_targets; do
      validate_platform_artifacts "$platform" || die "$platform remote build completed without the expected verified artifacts."
      BUILT_PLATFORMS="$(add_platform "$BUILT_PLATFORMS" "$platform")"
      write_state planned
    done
  fi

  all_selected_built || die "Not all selected platforms were built: selected=$PLATFORMS built=$BUILT_PLATFORMS"
  printf '%s\n' "$PLANNED_BUILD" > "$ROOT/BUILD_NUMBER.txt"
  PHASE="built"; write_state built
fi

load_state
if [[ "$PHASE" == built ]]; then
  for platform in $PLATFORMS; do validate_platform_artifacts "$platform" || die "Saved built phase is missing/invalid $platform artifacts."; done
  log "Committing and pushing public client release source"
  git add -- .gitignore README.md SECURITY.md RELEASE.md assets macos mobile desktop scripts homepage web VERSION.txt BUILD_NUMBER.txt ':(exclude)homepage/content.json'
  git diff --cached --check -- . ':(exclude)web/**' ':(exclude)homepage/content.json'
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
  if has_platform "$PLATFORMS" windows || has_platform "$PLATFORMS" linux; then
    "$ROOT/scripts/cleanup_desktop_remote_release.sh" "$RELEASE_TAG" || warn "Desktop worker cleanup failed; GitHub/homepage release is already complete."
  fi
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
