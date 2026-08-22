#!/usr/bin/env bash
# Deploy the Rantlist project homepage from the exact GitHub release tag supplied by the release workflow.
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$ROOT/homepage}"
REMOTE_URL="${REMOTE_URL:-https://mojoworks.xyz/labs/rantlist/}"
GITHUB_REPO="${GITHUB_REPO:-sylwesterdigital/rantlist-client}"
EXPECTED_RELEASE_TAG=""
RELEASE_CHANNEL="stable"
RELEASE_ARCH="universal2"
KEEP_BUILD=0
DO_DRY_RUN=0
source "$ROOT/scripts/release_profile.sh"

info(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok(){ printf '\033[1;32mOK\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
retry_cmd(){ local attempts="$1" delay="$2"; shift 2; local n=1; until "$@"; do local c=$?; (( n >= attempts )) && return "$c"; warn "Command failed ($n/$attempts); retrying in ${delay}s: $*"; sleep "$delay"; n=$((n+1)); done; }
usage(){ echo "Usage: ./scripts/deploy_homepage.sh --release-tag TAG [--dry-run] [--keep-build]"; }
while [[ $# -gt 0 ]]; do case "$1" in
  --release-tag) [[ $# -ge 2 ]] || die "--release-tag requires a value"; EXPECTED_RELEASE_TAG="$2"; shift 2;;
  --release-channel) RELEASE_CHANNEL="$2"; shift 2;;
  --release-arch) RELEASE_ARCH="$2"; shift 2;;
  --dry-run) DO_DRY_RUN=1; shift;;
  --keep-build) KEEP_BUILD=1; shift;;
  -h|--help) usage; exit 0;;
  *) die "Unknown option: $1";;
esac; done
[[ -n "$EXPECTED_RELEASE_TAG" ]] || die "--release-tag is required; homepage deployment must be pinned to the release just published."
[[ -d "$PROJECT_DIR" && -f "$PROJECT_DIR/index.html" ]] || die "Homepage source is missing: $PROJECT_DIR/index.html"
for t in gh python3 rsync ssh curl gzip; do command -v "$t" >/dev/null 2>&1 || die "Required tool missing: $t"; done
rantlist_load_release_profile || die "Unable to load local Rantlist website deployment profile."

STAMP="$(date +%Y%m%d%H%M%S)"
BUILD_ROOT="$PROJECT_DIR/.deploy_build"
BUILD_DIR="$BUILD_ROOT/rantlist-homepage-$STAMP"
mkdir -p "$BUILD_DIR"
cleanup(){ [[ "$KEEP_BUILD" == 1 ]] || rm -rf "$BUILD_DIR"; }
trap cleanup EXIT

info "Copying isolated homepage build"
rsync -a --delete --exclude '.deploy_build/' --exclude '.DS_Store' "$PROJECT_DIR/" "$BUILD_DIR/"

info "Resolving pinned GitHub release $EXPECTED_RELEASE_TAG"
API_JSON="$BUILD_DIR/.release.json"
gh api "repos/$GITHUB_REPO/releases/tags/$EXPECTED_RELEASE_TAG" > "$API_JSON"
BUILD_DIR="$BUILD_DIR" API_JSON="$API_JSON" EXPECTED_RELEASE_TAG="$EXPECTED_RELEASE_TAG" RELEASE_CHANNEL="$RELEASE_CHANNEL" RELEASE_ARCH="$RELEASE_ARCH" GITHUB_REPO="$GITHUB_REPO" REMOTE_URL="$REMOTE_URL" python3 <<'PY'
from pathlib import Path
import json, os, re
root=Path(os.environ['BUILD_DIR']); data=json.loads(Path(os.environ['API_JSON']).read_text())
tag=os.environ['EXPECTED_RELEASE_TAG']; channel=os.environ['RELEASE_CHANNEL']; arch=os.environ['RELEASE_ARCH'].lower(); repo=os.environ['GITHUB_REPO']
if data.get('draft'): raise SystemExit(f'Pinned release {tag} is still a draft')
if data.get('tag_name') != tag: raise SystemExit(f'GitHub returned {data.get("tag_name")!r}, expected {tag!r}')
if channel == 'stable' and data.get('prerelease'): raise SystemExit(f'{tag} is prerelease, not stable')
assets=data.get('assets') or []
def score(a):
    n=str(a.get('name','')).lower(); s=1000 if n.endswith('.dmg') else 600 if n.endswith('.zip') else -1000
    s += 250 if 'rantlist' in n else 0; s += 180 if arch in n else 0
    return s
asset=max(assets,key=score) if assets else None
if not asset or score(asset)<0: raise SystemExit(f'No suitable Rantlist macOS download asset found for {tag}')
release_url=str(data.get('html_url') or f'https://github.com/{repo}/releases/tag/{tag}')
download=str(asset.get('browser_download_url') or release_url); name=str(asset.get('name') or '')
page=root/'index.html'; doc=page.read_text()
for old,new in {
 '__LATEST_RELEASE_TAG__':tag,
 '__LATEST_RELEASE_NAME__':str(data.get('name') or tag),
 '__LATEST_RELEASE_URL__':release_url,
 '__LATEST_DOWNLOAD_URL__':download,
 '__LATEST_ASSET_NAME__':name,
}.items(): doc=doc.replace(old,new)
page.write_text(doc)
(root/'release.json').write_text(json.dumps({
 'product':'Rantlist','repository':repo,'tag':tag,'release_url':release_url,'download_url':download,
 'asset_name':name,'published_at':data.get('published_at') or data.get('created_at'),'deployment_url':os.environ['REMOTE_URL']
},indent=2)+'\n')
print(f'Pinned download: {name}')
PY
rm -f "$API_JSON"

grep -q "$EXPECTED_RELEASE_TAG" "$BUILD_DIR/index.html" || die "Pinned release tag was not inserted into homepage."
if grep -R "__LATEST_" "$BUILD_DIR" >/dev/null 2>&1; then die "Unresolved release placeholder remains in homepage build."; fi

info "Precompressing homepage"
find "$BUILD_DIR" -type f \( -name '*.html' -o -name '*.json' -o -name '*.css' -o -name '*.js' \) -print0 | while IFS= read -r -d '' f; do gzip -9 -kf "$f"; command -v brotli >/dev/null 2>&1 && brotli -f -q 11 "$f" || true; done

info "Deploying to $REMOTE_URL"
if [[ "$DO_DRY_RUN" == 0 ]]; then
  retry_cmd 4 8 ssh -o BatchMode=yes -o ConnectTimeout=15 -p "$RANTLIST_REMOTE_PORT" "$RANTLIST_REMOTE_USER@$RANTLIST_REMOTE_HOST" "mkdir -p '$RANTLIST_REMOTE_DIR'"
fi
flags=(-avz --human-readable --itemize-changes --chmod="$RANTLIST_REMOTE_CHMOD" --partial --partial-dir=.rsync-partial --delay-updates --delete-delay)
[[ "$DO_DRY_RUN" == 0 ]] || flags+=(--dry-run)
if rsync --help 2>&1 | grep -q -- '--chown'; then flags+=(--chown="$RANTLIST_REMOTE_OWNER"); fi
retry_cmd 4 10 rsync "${flags[@]}" -e "ssh -o BatchMode=yes -o ConnectTimeout=15 -p $RANTLIST_REMOTE_PORT" "$BUILD_DIR/" "$RANTLIST_REMOTE_USER@$RANTLIST_REMOTE_HOST:$RANTLIST_REMOTE_DIR/"

if [[ "$DO_DRY_RUN" == 0 ]]; then
  info "Verifying public Rantlist homepage"
  tmp="$(mktemp)"
  retry_cmd 4 8 curl --fail --silent --show-error --location "${REMOTE_URL%/}/?deploy=$STAMP" -o "$tmp"
  grep -qi '<title[^>]*>Rantlist' "$tmp" || die "Public page is reachable but Rantlist title verification failed."
  grep -F "$EXPECTED_RELEASE_TAG" "$tmp" >/dev/null || die "Public page does not contain pinned release $EXPECTED_RELEASE_TAG."
  rm -f "$tmp"
  ok "Deployed and verified $REMOTE_URL"
else
  ok "Homepage dry run completed"
fi
