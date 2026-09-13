#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for path in \
  web/index.html web/client-source.json macos/RantlistApp.swift homepage/index.html assets/rantlist-logo.svg \
  mobile/android/app/src/main/AndroidManifest.xml mobile/android/app/src/main/java/fun/workwork/rantlist/MainActivity.java \
  mobile/ios/Rantlist/RantlistApp.swift mobile/ios/Rantlist/Info.plist mobile/ios/Rantlist/Rantlist.entitlements mobile/ios/Rantlist.xcodeproj/project.pbxproj \
  mobile/ios/RantlistShare/ShareViewController.swift mobile/ios/RantlistShare/Info.plist mobile/ios/RantlistShare/RantlistShare.entitlements \
  scripts/source_release.js scripts/publish_macos_release.sh scripts/release_and_deploy_homepage.sh \
  scripts/release_signed.sh scripts/publish_github_release.sh scripts/verify_github_release_transaction.sh scripts/deploy_homepage.sh \
  scripts/check_macos_release_credentials.sh scripts/check_android_release_credentials.sh scripts/check_ios_release_credentials.sh \
  scripts/android_sdk.sh scripts/setup_android_release.sh scripts/build_android_release.sh scripts/build_ios_release.sh scripts/make_ios_push_only_project.js; do
  [[ -e "$ROOT/$path" ]] || { echo "Missing $path" >&2; exit 1; }
done
[[ -d "$ROOT/web/assets" ]] || { echo "Missing web/assets" >&2; exit 1; }
[[ -f "$ROOT/VERSION.txt" ]] || { echo "Missing VERSION.txt" >&2; exit 1; }
for script in "$ROOT"/scripts/*.sh "$ROOT"/scripts/*.js; do
  [[ -x "$script" ]] || { echo "Not executable: $script" >&2; exit 1; }
done
for script in "$ROOT"/scripts/*.sh; do
  bash -n "$script" || { echo "Invalid shell syntax: $script" >&2; exit 1; }
done
"$ROOT/scripts/verify_github_release_transaction.sh"
node "$ROOT/scripts/security_scan.js" "$ROOT"
grep -q 'rantlist-public-client-snapshot' "$ROOT/web/index.html" || { echo "web/index.html is not sanitized" >&2; exit 1; }
grep -q 'import AVFoundation' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS client lacks AVFoundation permission handling" >&2; exit 1; }
grep -q 'requestCaptureAuthorization(type)' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS WebKit media capture is not gated by native camera/microphone permission" >&2; exit 1; }
grep -q '!targetFrame.isMainFrame' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS client does not preserve embedded HTTPS frames in-app" >&2; exit 1; }
grep -q 'runOpenPanelWith parameters: WKOpenPanelParameters' "$ROOT/macos/RantlistApp.swift" || { echo "macOS native file chooser bridge missing" >&2; exit 1; }
grep -q 'navigationAction.navigationType == .linkActivated' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS client may launch external pages without a user click" >&2; exit 1; }
grep -q 'WKDownloadDelegate' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS native download delegate missing" >&2; exit 1; }
grep -q 'navigationAction.shouldPerformDownload' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS download navigation is not intercepted" >&2; exit 1; }
grep -q 'UIDocumentPickerViewController(forExporting:' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS download destination picker missing" >&2; exit 1; }
grep -q 'Content-Disposition' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS attachment responses are not routed to native downloads" >&2; exit 1; }
grep -q 'NSLocalNetworkUsageDescription' "$ROOT/mobile/ios/Rantlist/Info.plist" || { echo "iOS local-network call permission description missing" >&2; exit 1; }
! grep -q 'ignoresSafeArea(.keyboard, edges: .bottom)' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS wrapper still forces full-height layout behind the keyboard" >&2; exit 1; }
grep -q 'webView.scrollView.bounces = false' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS WKWebView bounce is not disabled" >&2; exit 1; }
grep -q 'webView.scrollView.alwaysBounceVertical = false' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS WKWebView vertical overscroll is not disabled" >&2; exit 1; }
grep -q 'webView.scrollView.alwaysBounceHorizontal = false' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS WKWebView horizontal overscroll is not disabled" >&2; exit 1; }
grep -q 'UIResponder.keyboardWillShowNotification' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS native keyboard will-show bridge missing" >&2; exit 1; }
grep -q 'UIResponder.keyboardDidHideNotification' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS native keyboard did-hide bridge missing" >&2; exit 1; }
grep -q 'rantlistNativeKeyboardPhase' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS UIKit keyboard lifecycle is not forwarded to the web UI" >&2; exit 1; }
grep -q 'import Network' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS native connectivity monitoring is missing" >&2; exit 1; }
grep -q 'NWPathMonitor' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS native offline recovery monitor is missing" >&2; exit 1; }
grep -q 'No internet connection' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS native offline screen is missing" >&2; exit 1; }
grep -q 'SplashLogo' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS startup splash logo is missing" >&2; exit 1; }
grep -q 'config.userContentController.add(context.coordinator, name: "rantlistBadge")' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS unread badge bridge missing" >&2; exit 1; }
grep -q 'setBadgeCount(count)' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS application icon badge update missing" >&2; exit 1; }
grep -q '@UIApplicationDelegateAdaptor(RantlistAppDelegate.self)' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS UIApplicationDelegate bridge for APNs missing" >&2; exit 1; }
grep -q 'requestAuthorization(options: \[.alert, .sound, .badge\])' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS notification alert/sound/badge permission request missing" >&2; exit 1; }
grep -q 'registerForRemoteNotifications()' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS APNs registration missing" >&2; exit 1; }
grep -q 'didRegisterForRemoteNotificationsWithDeviceToken' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS APNs device-token callback missing" >&2; exit 1; }
grep -q 'window.rantlistNativePushToken' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS APNs token is not forwarded into the authenticated web client" >&2; exit 1; }
grep -q '<key>aps-environment</key>' "$ROOT/mobile/ios/Rantlist/Rantlist.entitlements" || { echo "iOS aps-environment entitlement missing" >&2; exit 1; }
grep -q 'group.fun.workwork.rantlist' "$ROOT/mobile/ios/Rantlist/Rantlist.entitlements" || { echo "iOS App Group entitlement missing" >&2; exit 1; }
grep -q 'CODE_SIGN_ENTITLEMENTS = Rantlist/Rantlist.entitlements' "$ROOT/mobile/ios/Rantlist.xcodeproj/project.pbxproj" || { echo "iOS target is not wired to push/App Group entitlements" >&2; exit 1; }
grep -q 'com.apple.Push = {enabled = 1;}' "$ROOT/mobile/ios/Rantlist.xcodeproj/project.pbxproj" || { echo "Xcode Push Notifications capability missing" >&2; exit 1; }
grep -q 'RantlistShare.appex' "$ROOT/mobile/ios/Rantlist.xcodeproj/project.pbxproj" || { echo "iOS Share Extension target is not embedded" >&2; exit 1; }
grep -q 'com.apple.share-services' "$ROOT/mobile/ios/RantlistShare/Info.plist" || { echo "iOS Share Extension point identifier missing" >&2; exit 1; }
grep -q 'group.fun.workwork.rantlist' "$ROOT/mobile/ios/RantlistShare/RantlistShare.entitlements" || { echo "Share Extension App Group entitlement missing" >&2; exit 1; }
grep -q 'loadFileRepresentation' "$ROOT/mobile/ios/RantlistShare/ShareViewController.swift" || { echo "Share Extension does not copy shared media into the App Group inbox" >&2; exit 1; }
if command -v swiftc >/dev/null 2>&1; then
  swiftc -frontend -parse "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" >/dev/null || { echo "iOS host Swift source does not parse" >&2; exit 1; }
  swiftc -frontend -parse "$ROOT/mobile/ios/RantlistShare/ShareViewController.swift" >/dev/null || { echo "Share Extension Swift source does not parse" >&2; exit 1; }
fi
grep -q '"clientRole": "ios-share-extension"' "$ROOT/mobile/ios/RantlistShare/ShareViewController.swift" || { echo "Share Extension does not request its isolated server role" >&2; exit 1; }
grep -q 'recipientServiceReady' "$ROOT/mobile/ios/RantlistShare/ShareViewController.swift" || { echo "Share Extension can enable Send before authoritative destinations are ready" >&2; exit 1; }
! grep -q 'extensionContext?.open' "$ROOT/mobile/ios/RantlistShare/ShareViewController.swift" || { echo "Share Extension still attempts to launch the containing app" >&2; exit 1; }
grep -q 'RantlistShareSession' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "Host app does not persist the native Share Extension session snapshot" >&2; exit 1; }
grep -q 'session-v1.json' "$ROOT/mobile/ios/RantlistShare/ShareViewController.swift" || { echo "Share Extension does not read the atomic App Group session snapshot" >&2; exit 1; }
grep -q 'data.write(to: url, options: .atomic)' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "Host app Share Extension session snapshot is not atomic" >&2; exit 1; }
grep -q 'NativeShareSessionStore.save(body)' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "Host app does not update the Share Extension session snapshot" >&2; exit 1; }
grep -q 'URLSessionWebSocketTask' "$ROOT/mobile/ios/RantlistShare/ShareViewController.swift" || { echo "Share Extension does not use the direct Rantlist WebSocket transport" >&2; exit 1; }
grep -q 'native.share.destination' "$ROOT/mobile/ios/RantlistShare/ShareViewController.swift" || { echo "Share Extension destination selection protocol missing" >&2; exit 1; }
grep -q 'native.share.text' "$ROOT/mobile/ios/RantlistShare/ShareViewController.swift" || { echo "Share Extension direct text send protocol missing" >&2; exit 1; }
grep -q 'native.share.file.sent' "$ROOT/mobile/ios/RantlistShare/ShareViewController.swift" || { echo "Share Extension does not await authoritative file-send confirmation" >&2; exit 1; }
grep -q 'UISegmentedControl(items: \["Channels", "People"\])' "$ROOT/mobile/ios/RantlistShare/ShareViewController.swift" || { echo "Share Extension channel/people destination chooser missing" >&2; exit 1; }
! grep -q 'rantlist://share' "$ROOT/mobile/ios/RantlistShare/ShareViewController.swift" || { echo "Share Extension regressed to containing-app deep-link handoff" >&2; exit 1; }
! grep -q 'Open the app to choose where to send it' "$ROOT/mobile/ios/RantlistShare/ShareViewController.swift" || { echo "Share Extension still contains the obsolete bridge-page instruction" >&2; exit 1; }
grep -q 'deliverSharedFile(requestID:' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "Native shared-file recovery bridge missing" >&2; exit 1; }
grep -q 'window.rantlistNativeSharedItems' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "Native share inbox recovery is not delivered to the web client" >&2; exit 1; }
grep -q 'window.rantlistNativeSharedFileChunk' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "Native shared-file recovery chunks are not delivered to WKWebView" >&2; exit 1; }
grep -q 'function syncNativeShareSession' "$ROOT/web/index.html" || { echo "Web client does not synchronize Share Extension identity/destination state" >&2; exit 1; }
grep -q 'nativeSharePendingBar' "$ROOT/web/index.html" || { echo "Web client shared-item recovery bar missing" >&2; exit 1; }
[[ -f "$ROOT/web/assets/icons/drawing1.svg" ]] || { echo "Drawing attachment icon missing" >&2; exit 1; }
grep -q 'id="drawingActionButton" class="attachment-action" type="button"><span class="icon icon-drawing1"' "$ROOT/web/index.html" || { echo "First Drawing attachment action does not use drawing1.svg" >&2; exit 1; }
! grep -q 'id="drawingActionSelect"' "$ROOT/web/index.html" || { echo "Obsolete Drawing action select still present" >&2; exit 1; }
grep -q 'id="drawingLeaveButton" class="exit-control"' "$ROOT/web/index.html" || { echo "Drawing explicit leave/close control missing" >&2; exit 1; }
grep -q 'drawing-bottom-stroke-toolbar { order:0; width:100%; flex:1 1 100%;' "$ROOT/web/index.html" || { echo "Drawing bottom stroke toolbar wrapping missing" >&2; exit 1; }
grep -q '>Back to chat</span>' "$ROOT/web/index.html" || { echo "Drawing Back to chat label missing" >&2; exit 1; }
grep -q '>Close and Exit</span>' "$ROOT/web/index.html" || { echo "Drawing Close and Exit label missing" >&2; exit 1; }
grep -q 'word-break: keep-all;' "$ROOT/web/index.html" || { echo "Attachment labels can still split words" >&2; exit 1; }
grep -q 'drawing-stroke-preview-control' "$ROOT/web/index.html" || { echo "Drawing stroke-aware tool contrast missing" >&2; exit 1; }
grep -q "mobileRoomRailToggle: readStorage('chat.mobile.roomRailToggle') !== 'off'" "$ROOT/web/index.html" || { echo "Fresh-user Channel rail default is not enabled" >&2; exit 1; }

grep -q '\.native-share-pending\[hidden\].*display: none !important' "$ROOT/web/index.html" || { echo "Native shared-item pending bar can appear with no queued share payload" >&2; exit 1; }
grep -q 'RANTLIST_IOS_INSTALL_CONNECTED:-1' "$ROOT/scripts/build_ios_release.sh" || { echo "iOS release script does not default to connected-device install" >&2; exit 1; }
grep -q 'xcrun devicectl device install app' "$ROOT/scripts/build_ios_release.sh" || { echo "iOS release script does not install the archived app on connected development devices" >&2; exit 1; }
grep -q 'xcrun devicectl device process launch' "$ROOT/scripts/build_ios_release.sh" || { echo "iOS release script does not relaunch the installed app on connected development devices" >&2; exit 1; }
grep -q 'window.rantlistNativeSharedItems' "$ROOT/web/index.html" || { echo "Web client native Share Extension receiver missing" >&2; exit 1; }
grep -q 'window.rantlistNativeSharedFileChunk' "$ROOT/web/index.html" || { echo "Web client native shared-file chunk receiver missing" >&2; exit 1; }
grep -q "action: 'read'" "$ROOT/web/index.html" || { echo "Web client does not request shared files through the native bridge" >&2; exit 1; }
grep -q 'window.rantlistNativePushToken' "$ROOT/web/index.html" || { echo "Web client native APNs token receiver missing" >&2; exit 1; }
grep -q 'window.rantlistNativeAppState' "$ROOT/web/index.html" || { echo "Web client native foreground/background push state bridge missing" >&2; exit 1; }
grep -q 'window.rantlistNativeNotificationSettings' "$ROOT/web/index.html" || { echo "Web client native notification permission diagnostic bridge missing" >&2; exit 1; }
grep -q "appIconBadgeMode: \['off', 'direct', 'all'\].* : 'all'" "$ROOT/web/index.html" || { echo "Fresh native unread badge default is not enabled" >&2; exit 1; }
grep -q 'UIApplication.didEnterBackgroundNotification' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS app background lifecycle observer missing" >&2; exit 1; }
grep -q 'UIApplication.willResignActiveNotification' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS app inactive lifecycle observer missing" >&2; exit 1; }
grep -q 'window.rantlistNativeNotificationSettings' "$ROOT/mobile/ios/Rantlist/RantlistApp.swift" || { echo "iOS notification settings are not reported to the web client" >&2; exit 1; }
! grep -q 'PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"' "$ROOT/scripts/build_ios_release.sh" || { echo "iOS release script globally overrides the Share Extension bundle identifier" >&2; exit 1; }
grep -q 'RANTLIST_APP_BUNDLE_ID="$BUNDLE_ID"' "$ROOT/scripts/build_ios_release.sh" || { echo "iOS release script does not provide the shared bundle-id base to app + extension targets" >&2; exit 1; }
grep -q 'RANTLIST_IOS_SHARE_MODE:-auto' "$ROOT/scripts/build_ios_release.sh" || { echo "iOS release script lacks automatic Share provisioning fallback" >&2; exit 1; }
grep -q 'create_release_transactionally' "$ROOT/scripts/publish_github_release.sh" || { echo "GitHub release creation is not transaction-aware" >&2; exit 1; }
grep -q 'wait_for_github_tag' "$ROOT/scripts/publish_github_release.sh" || { echo "GitHub release flow does not wait for pushed-tag API visibility" >&2; exit 1; }
grep -q 'wait_for_release_resolution' "$ROOT/scripts/publish_github_release.sh" || { echo "GitHub release flow cannot reconcile ambiguous create state" >&2; exit 1; }
! grep -Eq 'retry_cmd[[:space:]].*gh[[:space:]]+release[[:space:]]+create' "$ROOT/scripts/publish_github_release.sh" || { echo "GitHub release creation still uses a blind retry loop" >&2; exit 1; }
grep -q 'com.apple.security.application-groups' "$ROOT/scripts/build_ios_release.sh" || { echo "iOS release script does not narrowly detect App Group provisioning failure" >&2; exit 1; }
grep -q 'make_ios_push_only_project.js' "$ROOT/scripts/build_ios_release.sh" || { echo "iOS release script does not generate the temporary push-only fallback project" >&2; exit 1; }
grep -q 'RantlistPushOnly.entitlements' "$ROOT/scripts/make_ios_push_only_project.js" || { echo "Push-only project generator does not preserve APNs entitlements" >&2; exit 1; }
grep -q 'config.userContentController.add(self, name: "rantlistBadge")' "$ROOT/macos/RantlistApp.swift" || { echo "macOS unread badge bridge missing" >&2; exit 1; }
grep -q 'NSApp.dockTile.badgeLabel' "$ROOT/macos/RantlistApp.swift" || { echo "macOS Dock badge update missing" >&2; exit 1; }
grep -q 'appIconBadgeSelect' "$ROOT/web/index.html" || { echo "Native unread badge Config control missing" >&2; exit 1; }
grep -q 'mediaAiModeSelect' "$ROOT/web/index.html" || { echo "Experimental image AI Config control missing" >&2; exit 1; }
! grep -RIn 'HETZNER_INFERENCE_API_KEY=' "$ROOT" --exclude='RELEASE.md' --exclude='README.md' --exclude='verify_client_repo.sh' >/dev/null 2>&1 || { echo "Public client must not contain a Hetzner API key setting" >&2; exit 1; }
[[ -f "$ROOT/mobile/ios/Rantlist/Assets.xcassets/SplashLogo.imageset/SplashLogo.png" ]] || { echo "iOS splash logo asset missing" >&2; exit 1; }
grep -q 'import Network' "$ROOT/macos/RantlistApp.swift" || { echo "macOS native connectivity monitoring is missing" >&2; exit 1; }
grep -q 'NWPathMonitor' "$ROOT/macos/RantlistApp.swift" || { echo "macOS native offline recovery monitor is missing" >&2; exit 1; }
grep -q 'No internet connection' "$ROOT/macos/RantlistApp.swift" || { echo "macOS native offline screen is missing" >&2; exit 1; }
grep -q 'android.permission.ACCESS_NETWORK_STATE' "$ROOT/mobile/android/app/src/main/AndroidManifest.xml" || { echo "Android network-state permission is missing" >&2; exit 1; }
grep -q 'registerDefaultNetworkCallback' "$ROOT/mobile/android/app/src/main/java/fun/workwork/rantlist/MainActivity.java" || { echo "Android native connectivity watcher is missing" >&2; exit 1; }
grep -q 'No internet connection' "$ROOT/mobile/android/app/src/main/java/fun/workwork/rantlist/MainActivity.java" || { echo "Android native offline screen is missing" >&2; exit 1; }
grep -q 'function isRantlistIOSApp()' "$ROOT/web/index.html" || { echo "iOS native viewport detection missing from web UI" >&2; exit 1; }
grep -q 'function setNativeIOSKeyboardState(open)' "$ROOT/web/index.html" || { echo "iOS native keyboard state isolation missing" >&2; exit 1; }
grep -q "root.style.setProperty('--app-height', '100dvh')" "$ROOT/web/index.html" || { echo "iOS native viewport still depends on animated pixel heights" >&2; exit 1; }
grep -q 'data-native-ios-app="true"' "$ROOT/web/index.html" || { echo "iOS keyboard motion suppression missing" >&2; exit 1; }
grep -q 'overflow-anchor: none' "$ROOT/web/index.html" || { echo "iOS message timeline scroll anchoring is not disabled" >&2; exit 1; }
grep -q 'native-ios-keyboard-transition' "$ROOT/web/index.html" || { echo "iOS message timeline keyboard freeze is missing" >&2; exit 1; }
grep -q 'mobileTypingFocusInput' "$ROOT/web/index.html" || { echo "Mobile typing-focus config toggle is missing" >&2; exit 1; }
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
