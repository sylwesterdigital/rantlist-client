#!/usr/bin/env bash
# Update homepage/content.json only. This does not build clients, create a Git tag,
# publish a GitHub Release, or replace the homepage HTML/release metadata.
set -Eeuo pipefail
IFS=$' \n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTENT="$ROOT/homepage/content.json"
REMOTE_URL="${REMOTE_URL:-https://mojoworks.xyz/labs/rantlist/}"
DO_DRY_RUN=0
source "$ROOT/scripts/release_profile.sh"

info(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok(){ printf '\033[1;32mOK\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
usage(){ echo "Usage: ./scripts/deploy_homepage_content.sh [--dry-run]"; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DO_DRY_RUN=1; shift;;
    -h|--help) usage; exit 0;;
    *) die "Unknown option: $1";;
  esac
done

[[ -s "$CONTENT" ]] || die "Missing homepage/content.json"
for tool in node rsync ssh curl gzip shasum; do command -v "$tool" >/dev/null 2>&1 || die "Required tool missing: $tool"; done
"$ROOT/scripts/verify_homepage_content.js"
rantlist_load_release_profile || die "Unable to load local Rantlist website deployment profile."

TMP="$(mktemp -d /tmp/rantlist-homepage-content.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
if [[ "$DO_DRY_RUN" == 0 ]]; then
  CURRENT_PAGE="$TMP/current-homepage.html"
  curl --fail --silent --show-error --location "${REMOTE_URL%/}/?content-check=$(date +%s)" -o "$CURRENT_PAGE"
  grep -F 'id="showcase"' "$CURRENT_PAGE" >/dev/null || die "The public homepage does not have the JSON-driven showcase yet. Let one normal homepage/release deployment install it first."
fi
cp "$CONTENT" "$TMP/content.json"
gzip -9 -kf "$TMP/content.json"
HAS_BROTLI=0
if command -v brotli >/dev/null 2>&1; then
  brotli -f -q 11 "$TMP/content.json"
  HAS_BROTLI=1
fi

info "Updating Rantlist homepage video/gallery content only"
if [[ "$DO_DRY_RUN" == 0 ]]; then
  ssh -o BatchMode=yes -o ConnectTimeout=15 -p "$RANTLIST_REMOTE_PORT" "$RANTLIST_REMOTE_USER@$RANTLIST_REMOTE_HOST" "mkdir -p '$RANTLIST_REMOTE_DIR'"
  if [[ "$HAS_BROTLI" == 0 ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=15 -p "$RANTLIST_REMOTE_PORT" "$RANTLIST_REMOTE_USER@$RANTLIST_REMOTE_HOST" "rm -f '$RANTLIST_REMOTE_DIR/content.json.br'"
  fi
fi
flags=(-avz --human-readable --itemize-changes --chmod="$RANTLIST_REMOTE_CHMOD" --partial --delay-updates)
[[ "$DO_DRY_RUN" == 0 ]] || flags+=(--dry-run)
if rsync --help 2>&1 | grep -q -- '--chown'; then flags+=(--chown="$RANTLIST_REMOTE_OWNER"); fi
rsync "${flags[@]}" -e "ssh -o BatchMode=yes -o ConnectTimeout=15 -p $RANTLIST_REMOTE_PORT" "$TMP/" "$RANTLIST_REMOTE_USER@$RANTLIST_REMOTE_HOST:$RANTLIST_REMOTE_DIR/"

if [[ "$DO_DRY_RUN" == 0 ]]; then
  info "Verifying public homepage content JSON"
  FETCHED="$TMP/public-content.json"
  curl --fail --silent --show-error --location "${REMOTE_URL%/}/content.json?content=$(date +%s)" -o "$FETCHED"
  node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));' "$FETCHED"
  local_sha="$(shasum -a 256 "$CONTENT" | awk '{print $1}')"
  remote_sha="$(shasum -a 256 "$FETCHED" | awk '{print $1}')"
  [[ "$local_sha" == "$remote_sha" ]] || die "Public content.json does not match the local file after deployment."
  ok "Homepage video/gallery content updated without creating a client release."
else
  ok "Homepage content dry run completed."
fi
