#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for path in \
  web/index.html web/client-source.json macos/RantlistApp.swift homepage/index.html assets/rantlist-logo.svg \
  mobile/android/app/src/main/AndroidManifest.xml mobile/android/app/src/main/java/fun/workwork/rantlist/MainActivity.java \
  mobile/ios/Rantlist/RantlistApp.swift mobile/ios/Rantlist/Info.plist mobile/ios/Rantlist.xcodeproj/project.pbxproj \
  scripts/source_release.js scripts/publish_macos_release.sh scripts/release_and_deploy_homepage.sh \
  scripts/release_signed.sh scripts/publish_github_release.sh scripts/deploy_homepage.sh \
  scripts/check_macos_release_credentials.sh scripts/check_android_release_credentials.sh scripts/check_ios_release_credentials.sh \
  scripts/build_android_release.sh scripts/build_ios_release.sh; do
  [[ -e "$ROOT/$path" ]] || { echo "Missing $path" >&2; exit 1; }
done
[[ -d "$ROOT/web/assets" ]] || { echo "Missing web/assets" >&2; exit 1; }
[[ -f "$ROOT/VERSION.txt" ]] || { echo "Missing VERSION.txt" >&2; exit 1; }
for script in "$ROOT"/scripts/*.sh "$ROOT"/scripts/*.js; do
  [[ -x "$script" ]] || { echo "Not executable: $script" >&2; exit 1; }
done
node "$ROOT/scripts/security_scan.js" "$ROOT"
grep -q 'rantlist-public-client-snapshot' "$ROOT/web/index.html" || { echo "web/index.html is not sanitized" >&2; exit 1; }
grep -q 'import AVFoundation' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS client lacks AVFoundation permission handling" >&2; exit 1; }
grep -q 'requestCaptureAuthorization(type)' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS WebKit media capture is not gated by native camera/microphone permission" >&2; exit 1; }
grep -q 'NSLocalNetworkUsageDescription' "$ROOT/mobile/ios/Rantlist/Info.plist" || { echo "iOS local-network call permission description missing" >&2; exit 1; }
grep -q 'syncRemoteCallTrackState' "$ROOT/web/index.html" || { echo "WebRTC remote video track synchronization missing" >&2; exit 1; }
grep -q "video.setAttribute('webkit-playsinline', '')" "$ROOT/web/index.html" || { echo "WebKit inline remote video playback safeguard missing" >&2; exit 1; }
REPO_VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION.txt")"
SOURCE_VERSION="$(node -e 'const p=require(process.argv[1]); process.stdout.write(String(p.sourceVersion||""))' "$ROOT/web/client-source.json")"
[[ "$REPO_VERSION" == "$SOURCE_VERSION" ]] || { echo "VERSION.txt ($REPO_VERSION) does not match synchronized source version ($SOURCE_VERSION). Run scripts/sync_from_stage.sh." >&2; exit 1; }
[[ "$REPO_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid synchronized version: $REPO_VERSION" >&2; exit 1; }
grep -q 'https://mojoworks.xyz/labs/rantlist/' "$ROOT/homepage/index.html" || { echo "Rantlist homepage target missing" >&2; exit 1; }
if grep -RInE 'RANTLIST_REMOTE_PORT=.*[0-9]{2,5}' "$ROOT/scripts" >/dev/null 2>&1; then
  echo "Public repository contains a hard-coded SSH deployment port." >&2
  exit 1
fi
echo "Rantlist public client repository verification passed (source version $REPO_VERSION)."
