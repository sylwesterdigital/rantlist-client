#!/usr/bin/env bash
# Offline regression test for the GitHub release transaction state machine.
# No network access or GitHub credentials are used.
set -Eeuo pipefail
IFS=$' \n\t'

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBLISH="$ROOT/scripts/publish_github_release.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/rantlist-gh-release-test.XXXXXX")"
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

fail(){ printf 'GitHub release transaction verification failed: %s\n' "$*" >&2; exit 1; }
[[ -x "$PUBLISH" ]] || fail "publish_github_release.sh is missing or not executable"
bash -n "$PUBLISH" || fail "publish_github_release.sh has invalid shell syntax"

mkdir -p "$TMP/client/scripts" "$TMP/client/release" "$TMP/client/web" "$TMP/bin" "$TMP/state"
cp "$PUBLISH" "$TMP/client/scripts/publish_github_release.sh"
printf '9.9.999\n' > "$TMP/client/VERSION.txt"
printf '999\n' > "$TMP/client/BUILD_NUMBER.txt"
printf '{"sourceRevision":"rantlist-deploy-r999"}\n' > "$TMP/client/web/client-source.json"
BASE="$TMP/client/release/Rantlist-v9.9.999-b999"
printf 'dmg\n' > "${BASE}-macOS-universal2.dmg"
printf 'zip\n' > "${BASE}-macOS-universal2.zip"
printf 'ipa\n' > "${BASE}-iOS.ipa"
(
  cd "$TMP/client/release"
  shasum -a 256 Rantlist-v9.9.999-b999-macOS-universal2.dmg Rantlist-v9.9.999-b999-macOS-universal2.zip > Rantlist-v9.9.999-b999-SHA256.txt
  shasum -a 256 Rantlist-v9.9.999-b999-iOS.ipa > Rantlist-v9.9.999-b999-iOS-SHA256.txt
)

cat > "$TMP/bin/git" <<'MOCKGIT'
#!/usr/bin/env bash
case "$1" in
  show-ref) exit 0 ;;
  rev-list) printf '%040d\n' 0 | tr 0 a ;;
  push) exit 0 ;;
  *) printf 'unexpected git call: %s\n' "$*" >&2; exit 2 ;;
esac
MOCKGIT

cat > "$TMP/bin/gh" <<'MOCKGH'
#!/usr/bin/env bash
set -u
STATE="${MOCK_STATE:?}"
if [[ "$1" == auth && "$2" == status ]]; then exit 0; fi
if [[ "$1" == api ]]; then
  shift
  method=GET
  args=("$@")
  for ((i=0; i<${#args[@]}; i++)); do
    [[ "${args[$i]}" == --method ]] && method="${args[$((i+1))]}"
  done
  endpoint=""
  for arg in "${args[@]}"; do [[ "$arg" == repos/* ]] && endpoint="$arg"; done
  if [[ "$method" == GET && "$endpoint" == */commits/* ]]; then printf '%040d\n' 0 | tr 0 a; exit 0; fi
  if [[ "$method" == GET && "$endpoint" == */releases/tags/* ]]; then
    [[ -f "$STATE/release" ]] && { cat "$STATE/release"; exit 0; }
    if [[ "${MOCK_SCENARIO:-}" == indeterminate && -f "$STATE/after_post" ]]; then
      printf 'gh: Internal Server Error (HTTP 500)\n' >&2
      exit 1
    fi
    printf 'gh: Not Found (HTTP 404)\n' >&2
    exit 1
  fi
  if [[ "$method" == POST && "$endpoint" == */releases ]]; then
    count=0; [[ -f "$STATE/posts" ]] && count="$(cat "$STATE/posts")"
    count=$((count + 1)); printf '%s\n' "$count" > "$STATE/posts"
    case "${MOCK_SCENARIO:-ambiguous}:$count" in
      ambiguous:1) printf '777\n' > "$STATE/release"; printf 'HTTP 500 (mock ambiguous response)\n' >&2; exit 1 ;;
      retry:1) printf 'HTTP 500 (mock pre-commit response)\n' >&2; exit 1 ;;
      indeterminate:1) touch "$STATE/after_post"; printf 'HTTP 500 (mock ambiguous response)\n' >&2; exit 1 ;;
    esac
    printf '888\n' > "$STATE/release"; printf '888\n'; exit 0
  fi
  printf 'unexpected gh api call: %s\n' "$*" >&2; exit 2
fi
if [[ "$1" == release && "$2" == upload ]]; then exit 0; fi
if [[ "$1" == release && "$2" == edit ]]; then exit 0; fi
if [[ "$1" == release && "$2" == view ]]; then
  joined="$*"
  if [[ "$joined" == *"--json assets"* ]]; then
    printf '%s\n' \
      Rantlist-v9.9.999-b999-macOS-universal2.dmg \
      Rantlist-v9.9.999-b999-macOS-universal2.zip \
      Rantlist-v9.9.999-b999-SHA256.txt \
      Rantlist-v9.9.999-b999-iOS.ipa \
      Rantlist-v9.9.999-b999-iOS-SHA256.txt
  elif [[ "$joined" == *"--json isDraft"* ]]; then
    printf 'false\n'
  elif [[ "$joined" == *"--json url"* ]]; then
    printf 'https://example.invalid/release\n'
  else
    exit 2
  fi
  exit 0
fi
printf 'unexpected gh call: %s\n' "$*" >&2
exit 2
MOCKGH
chmod +x "$TMP/bin/git" "$TMP/bin/gh"

run_case(){
  local scenario="$1" expected_posts="$2" output
  output="$TMP/${scenario}.log"
  rm -f "$TMP/state"/*
  (
    cd "$TMP/client"
    PATH="$TMP/bin:$PATH" \
    MOCK_STATE="$TMP/state" MOCK_SCENARIO="$scenario" RELEASE_PLATFORMS='macos ios' \
    GITHUB_TAG_VISIBILITY_ATTEMPTS=1 GITHUB_TAG_VISIBILITY_DELAY=0 \
    GITHUB_RELEASE_RECOVERY_ATTEMPTS=1 GITHUB_RELEASE_RECOVERY_DELAY=0 GITHUB_RELEASE_ABSENCE_CONFIRMATIONS=1 \
    GITHUB_CREATE_RETRY_DELAY=0 \
    bash scripts/publish_github_release.sh
  ) >"$output" 2>&1 || { cat "$output" >&2; fail "$scenario scenario failed"; }
  [[ -f "$TMP/state/posts" ]] || fail "$scenario scenario never attempted release creation"
  [[ "$(cat "$TMP/state/posts")" == "$expected_posts" ]] || fail "$scenario scenario used the wrong number of create POSTs"
  ! grep -q 'WARNING:' "$output" || fail "$scenario scenario leaked retry warnings"
}


run_failure_case(){
  local scenario="$1" expected_posts="$2" output
  output="$TMP/${scenario}.log"
  rm -f "$TMP/state"/*
  if (
    cd "$TMP/client"
    PATH="$TMP/bin:$PATH" \
    MOCK_STATE="$TMP/state" MOCK_SCENARIO="$scenario" RELEASE_PLATFORMS='macos ios' \
    GITHUB_TAG_VISIBILITY_ATTEMPTS=1 GITHUB_TAG_VISIBILITY_DELAY=0 \
    GITHUB_RELEASE_RECOVERY_ATTEMPTS=1 GITHUB_RELEASE_RECOVERY_DELAY=0 GITHUB_RELEASE_ABSENCE_CONFIRMATIONS=1 \
    GITHUB_CREATE_RETRY_DELAY=0 \
    bash scripts/publish_github_release.sh
  ) >"$output" 2>&1; then
    cat "$output" >&2
    fail "$scenario scenario unexpectedly succeeded"
  fi
  [[ -f "$TMP/state/posts" ]] || fail "$scenario scenario never attempted release creation"
  [[ "$(cat "$TMP/state/posts")" == "$expected_posts" ]] || fail "$scenario scenario repeated an ambiguous create POST"
}

run_case ambiguous 1
grep -q 'recovered release id 777 without repeating the create request' "$TMP/ambiguous.log" \
  || fail "ambiguous 5xx was not recovered from remote state"
run_case retry 2
grep -q 'Created draft GitHub Release v9.9.999-b999 (id 888)' "$TMP/retry.log" \
  || fail "confirmed-absent release was not retried successfully"
run_failure_case indeterminate 1
grep -q 'refusing a potentially duplicate create request' "$TMP/indeterminate.log" \
  || fail "indeterminate remote state did not stop publication safely"

printf 'GitHub release transaction verification passed: ambiguous 5xx recovery is idempotent, absence-gated and fail-closed.\n'
