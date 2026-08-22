#!/usr/bin/env bash
# Deploy the Rantlist project homepage. The current release tag is pinned; missing platform downloads may use the newest earlier verified release containing that platform.
set -Eeuo pipefail
IFS=$' \n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$ROOT/homepage}"
REMOTE_URL="${REMOTE_URL:-https://mojoworks.xyz/labs/rantlist/}"
GITHUB_REPO="${GITHUB_REPO:-sylwesterdigital/rantlist-client}"
EXPECTED_RELEASE_TAG=""
RELEASE_CHANNEL="stable"
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
  --release-arch) shift 2;; # compatibility with older caller; asset detection is now platform-aware
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

info "Resolving pinned GitHub release $EXPECTED_RELEASE_TAG and platform downloads"
PINNED_JSON="$BUILD_DIR/.pinned-release.json"
RELEASES_JSON="$BUILD_DIR/.releases.json"
gh api "repos/$GITHUB_REPO/releases/tags/$EXPECTED_RELEASE_TAG" > "$PINNED_JSON"
gh api "repos/$GITHUB_REPO/releases?per_page=100" > "$RELEASES_JSON"
BUILD_DIR="$BUILD_DIR" PINNED_JSON="$PINNED_JSON" RELEASES_JSON="$RELEASES_JSON" EXPECTED_RELEASE_TAG="$EXPECTED_RELEASE_TAG" RELEASE_CHANNEL="$RELEASE_CHANNEL" GITHUB_REPO="$GITHUB_REPO" REMOTE_URL="$REMOTE_URL" python3 <<'PY'
from pathlib import Path
import html, json, os
root=Path(os.environ['BUILD_DIR'])
pinned=json.loads(Path(os.environ['PINNED_JSON']).read_text())
releases=json.loads(Path(os.environ['RELEASES_JSON']).read_text())
tag=os.environ['EXPECTED_RELEASE_TAG']; channel=os.environ['RELEASE_CHANNEL']; repo=os.environ['GITHUB_REPO']
if pinned.get('draft'): raise SystemExit(f'Pinned release {tag} is still a draft')
if pinned.get('tag_name') != tag: raise SystemExit(f'GitHub returned {pinned.get("tag_name")!r}, expected {tag!r}')
if channel == 'stable' and pinned.get('prerelease'): raise SystemExit(f'{tag} is prerelease, not stable')
if channel == 'prerelease' and not pinned.get('prerelease'): raise SystemExit(f'{tag} is stable, not prerelease')
if not isinstance(releases,list): raise SystemExit('GitHub releases list response is invalid')

def acceptable(r):
    if r.get('draft'): return False
    if channel == 'stable' and r.get('prerelease'): return False
    if channel == 'prerelease' and not r.get('prerelease'): return False
    return True

def match(asset, kind):
    n=str(asset.get('name','')).lower()
    if 'rantlist' not in n: return False
    if kind=='macos': return n.endswith('.dmg') and 'macos' in n
    if kind=='android_apk': return n.endswith('.apk') and 'android' in n
    if kind=='android_aab': return n.endswith('.aab') and 'android' in n
    if kind=='ios': return n.endswith('.ipa') and ('ios' in n or 'iphone' in n)
    return False

def find_in_release(r,kind):
    for a in r.get('assets') or []:
        if match(a,kind): return a
    return None

def resolve(kind):
    a=find_in_release(pinned,kind)
    if a: return pinned,a
    for r in releases:
        if acceptable(r):
            a=find_in_release(r,kind)
            if a: return r,a
    return None,None

resolved={}
for kind in ('macos','android_apk','android_aab','ios'):
    r,a=resolve(kind)
    if a:
        resolved[kind]={
            'tag':str(r.get('tag_name') or ''),
            'name':str(a.get('name') or ''),
            'url':str(a.get('browser_download_url') or ''),
            'release_url':str(r.get('html_url') or f'https://github.com/{repo}/releases/tag/{r.get("tag_name","")}')
        }

buttons=[]
def button(kind,label,primary=False):
    d=resolved.get(kind)
    if not d: return
    cls='pill primary' if primary else 'pill'
    title=f'{label} — {d["tag"]}'
    buttons.append(f'<a class="{cls}" data-rantlist-download="{html.escape(kind)}" title="{html.escape(title)}" href="{html.escape(d["url"],quote=True)}">{html.escape(label)}</a>')
button('macos','Download for macOS',True)
button('android_apk','Android APK',not buttons)
button('ios','iOS IPA',not buttons)

release_url=str(pinned.get('html_url') or f'https://github.com/{repo}/releases/tag/{tag}')
page=root/'index.html'; doc=page.read_text()
for old,new in {
 '__LATEST_RELEASE_TAG__':tag,
 '__LATEST_RELEASE_NAME__':str(pinned.get('name') or tag),
 '__LATEST_RELEASE_URL__':release_url,
 '__PLATFORM_DOWNLOAD_BUTTONS__':'\n        '.join(buttons),
}.items(): doc=doc.replace(old,new)
page.write_text(doc)
(root/'release.json').write_text(json.dumps({
 'product':'Rantlist','repository':repo,'tag':tag,'release_url':release_url,
 'published_at':pinned.get('published_at') or pinned.get('created_at'),
 'downloads':resolved,'deployment_url':os.environ['REMOTE_URL']
},indent=2)+'\n')
print('Pinned release:',tag)
for kind,d in resolved.items(): print(f'{kind}: {d["tag"]} -> {d["name"]}')
PY
rm -f "$PINNED_JSON" "$RELEASES_JSON"

grep -q "$EXPECTED_RELEASE_TAG" "$BUILD_DIR/index.html" || die "Pinned release tag was not inserted into homepage."
if grep -R "__LATEST_\|__PLATFORM_" "$BUILD_DIR" >/dev/null 2>&1; then die "Unresolved release placeholder remains in homepage build."; fi

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
