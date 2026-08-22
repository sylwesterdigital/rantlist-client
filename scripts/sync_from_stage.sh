#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_PROJECT="${SOURCE_PROJECT:-/Users/smielniczuk/Documents/works/stage/chat}"
TARGET_WEB="$REPO_ROOT/web"
TMP_DIR="$REPO_ROOT/.client-sync.$$"

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

command -v node >/dev/null 2>&1 || die "Node.js is required for the sanitizer/security scan."
command -v rsync >/dev/null 2>&1 || die "rsync is required."
[[ -x "$REPO_ROOT/scripts/source_release.js" ]] || die "Missing executable scripts/source_release.js"
[[ -f "$SOURCE_PROJECT/index.html" ]] || die "Missing $SOURCE_PROJECT/index.html"
[[ -d "$SOURCE_PROJECT/assets" ]] || die "Missing $SOURCE_PROJECT/assets"

log "Verifying Rantlist source version metadata"
SOURCE_VERSION="$(node "$REPO_ROOT/scripts/source_release.js" "$SOURCE_PROJECT" --field version)"
SOURCE_REVISION="$(node "$REPO_ROOT/scripts/source_release.js" "$SOURCE_PROJECT" --field revision)"

mkdir -p "$TMP_DIR/web"
log "Copying allow-listed browser client from $SOURCE_PROJECT"
cp "$SOURCE_PROJECT/index.html" "$TMP_DIR/web/index.html"
rsync -a --delete \
  --exclude '.DS_Store' \
  --exclude '*.pem' --exclude '*.key' --exclude '*.p12' --exclude '*.pfx' \
  "$SOURCE_PROJECT/assets/" "$TMP_DIR/web/assets/"

log "Sanitizing public client snapshot"
node "$REPO_ROOT/scripts/sanitize_client.js" "$TMP_DIR/web"

cat > "$TMP_DIR/web/client-source.json" <<JSON
{
  "sourceVersion": "$SOURCE_VERSION",
  "sourceRevision": "$SOURCE_REVISION",
  "sourceKind": "sanitized-browser-client",
  "versionAuthority": "stage/chat",
  "serverCodeIncluded": false
}
JSON

log "Running security scan before publishing files"
node "$REPO_ROOT/scripts/security_scan.js" "$TMP_DIR"

log "Replacing managed web/ snapshot atomically"
rm -rf "$TARGET_WEB.next"
mv "$TMP_DIR/web" "$TARGET_WEB.next"
rm -rf "$TARGET_WEB"
mv "$TARGET_WEB.next" "$TARGET_WEB"

# VERSION.txt is not an independent client version. It mirrors the verified
# source application version and is consumed by the macOS bundle/release builder.
printf '%s\n' "$SOURCE_VERSION" > "$REPO_ROOT/VERSION.txt"

log "Client snapshot synchronized"
printf 'Source UI/version: %s\nSource revision: %s\nClient release version: %s (mirrors stage/chat)\n' \
  "$SOURCE_VERSION" "$SOURCE_REVISION" "$SOURCE_VERSION"
if command -v git >/dev/null 2>&1 && git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf '\nGit changes:\n'
  git -C "$REPO_ROOT" status --short -- VERSION.txt web || true
fi
