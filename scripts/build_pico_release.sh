#!/usr/bin/env bash
# Prepare and validate the Rantlist PICO Web App release artifact.
# PICO Web Apps are URL/manifest submissions; no APK/AAB is generated.
set -Eeuo pipefail
IFS=$' \n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die(){ printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

CONFIG="$ROOT/mobile/pico/webapp-release.json"
RELEASE_DIR="$ROOT/release"
BUILD_ROOT="$ROOT/.pico-webapp-build"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION.txt")"
BUILD_NUMBER="${BUILD_NUMBER_OVERRIDE:-$(tr -cd '0-9' < "$ROOT/BUILD_NUMBER.txt" 2>/dev/null || true)}"
BUILD_NUMBER="${BUILD_NUMBER:-0}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid VERSION.txt: $VERSION"
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || die "Invalid build number: $BUILD_NUMBER"
(( BUILD_NUMBER > 0 )) || die "PICO release requires BUILD_NUMBER_OVERRIDE or a positive BUILD_NUMBER.txt"
[[ -s "$CONFIG" ]] || die "Missing PICO Web App config: $CONFIG"
for tool in node curl zip shasum; do command -v "$tool" >/dev/null 2>&1 || die "Required tool missing: $tool"; done

APP_URL="$(node -e 'const p=require(process.argv[1]);process.stdout.write(p.appUrl||"")' "$CONFIG")"
MANIFEST_URL="$(node -e 'const p=require(process.argv[1]);process.stdout.write(p.manifestUrl||"")' "$CONFIG")"
[[ "$APP_URL" == https://* ]] || die "PICO appUrl must be HTTPS"
[[ "$MANIFEST_URL" == https://* ]] || die "PICO manifestUrl must be HTTPS"

STEM="Rantlist-v${VERSION}-b${BUILD_NUMBER}"
ZIP_OUT="$RELEASE_DIR/${STEM}-pico-webapp.zip"
SHA_OUT="$RELEASE_DIR/${STEM}-pico-SHA256.txt"
STAGE="$BUILD_ROOT/${STEM}-pico-webapp"
rm -rf "$BUILD_ROOT"
mkdir -p "$STAGE" "$RELEASE_DIR"

log "Validating live PICO Web App: $APP_URL"
curl --fail --silent --show-error --location --max-time 25 "$APP_URL" -o "$STAGE/index.html"
[[ -s "$STAGE/index.html" ]] || die "PICO app URL returned an empty document"

log "Fetching PWA manifest: $MANIFEST_URL"
curl --fail --silent --show-error --location --max-time 25 "$MANIFEST_URL" -o "$STAGE/manifest.webmanifest"
[[ -s "$STAGE/manifest.webmanifest" ]] || die "PICO manifest URL returned an empty document"

node - "$CONFIG" "$STAGE/manifest.webmanifest" <<'NODE'
const fs=require('fs');
const [configPath,manifestPath]=process.argv.slice(2);
const c=JSON.parse(fs.readFileSync(configPath,'utf8'));
const m=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
for(const [key,value] of Object.entries(c.expected||{})){
  if(m[key]!==value) throw new Error(`manifest ${key}=${JSON.stringify(m[key])}, expected ${JSON.stringify(value)}`);
}
if(!Array.isArray(m.icons) || !m.icons.some(x=>String(x.sizes||'').includes('192x192')) || !m.icons.some(x=>String(x.sizes||'').includes('512x512'))){
  throw new Error('manifest must provide 192x192 and 512x512 icons');
}
if(c.distribution?.developerPortalType!=='Web App' || c.distribution?.binaryRequired!==false){
  throw new Error('PICO release config must remain a URL-based Web App target');
}
console.log('PICO Web App manifest contract passed.');
NODE

cp "$CONFIG" "$STAGE/webapp-release.json"
node - "$CONFIG" "$STAGE/release.json" "$VERSION" "$BUILD_NUMBER" <<'NODE'
const fs=require('fs');
const [configPath,out,version,build]=process.argv.slice(2);
const c=JSON.parse(fs.readFileSync(configPath,'utf8'));
fs.writeFileSync(out,JSON.stringify({
  product:'Rantlist', platform:'PICO', kind:'Web App', version,
  build:Number(build), appUrl:c.appUrl, manifestUrl:c.manifestUrl,
  distribution:c.distribution,
  preparedAt:new Date().toISOString()
},null,2)+'\n');
NODE
cat > "$STAGE/PICO-SUBMISSION.txt" <<EOF
Rantlist PICO Web App release
Version: $VERSION
Build: $BUILD_NUMBER
App URL: $APP_URL
Manifest URL: $MANIFEST_URL

PICO Developer Platform:
- Create/select the Rantlist app.
- Platform: PICO.
- Enable "This is a Web App".
- Submit the hosted Rantlist Web App URL according to the current PICO Web App workflow.

This bundle is the GitHub audit/snapshot artifact. It is not an APK or AAB.
EOF

rm -f "$ZIP_OUT" "$SHA_OUT"
(
  cd "$BUILD_ROOT"
  zip -qr "$ZIP_OUT" "$(basename "$STAGE")"
)
[[ -s "$ZIP_OUT" ]] || die "PICO Web App ZIP was not produced"
(
  cd "$RELEASE_DIR"
  shasum -a 256 "$(basename "$ZIP_OUT")" > "$(basename "$SHA_OUT")"
  shasum -a 256 -c "$(basename "$SHA_OUT")" >/dev/null
)

if [[ "${RANTLIST_PICO_LAUNCH_TEST:-0}" == 1 ]]; then
  if command -v pico-cli >/dev/null 2>&1; then
    log "Launching Web App on PICO through installed pico-cli"
    if pico-cli url launch --help >/dev/null 2>&1; then
      pico-cli url launch --manifest-url "$MANIFEST_URL" ${RANTLIST_PICO_DEVICE:+--device "$RANTLIST_PICO_DEVICE"}
    elif pico-cli web launch --help >/dev/null 2>&1; then
      warn "Installed PICO CLI uses legacy web launch command"
      pico-cli web launch --manifest-url "$MANIFEST_URL" ${RANTLIST_PICO_DEVICE:+--device "$RANTLIST_PICO_DEVICE"}
    else
      die "Installed pico-cli has no supported Web App launch command"
    fi
  else
    die "RANTLIST_PICO_LAUNCH_TEST=1 but pico-cli is not installed"
  fi
fi

printf '\nRantlist PICO Web App release prepared.\nBundle: %s\nSHA: %s\n' "$ZIP_OUT" "$SHA_OUT"
