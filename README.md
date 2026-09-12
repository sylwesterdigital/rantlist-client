## v0.1.66 / 9.6.227

- Synchronized browser client to **9.6.227 / rantlist-deploy-r255** and protocol **63**.
- Fleet Battle sizes both mobile square harbours from the real rendered stage instead of a fixed `100dvh` reserve, preventing bottom-row clipping in the iOS WKWebView.
- Normal planning controls stay on one compact row; the Fleet title/match phase is one line and redundant mobile status copy remains collapsed.
- Active player video tiles are enlarged to 64×36 CSS pixels; extremely short screens scroll the board area rather than hiding untappable cells.

## v0.1.65 / 9.6.226

- Synchronized browser client to **9.6.226 / rantlist-deploy-r254** and protocol **63**.
- Fleet Battle mobile boards size from both the post-Channel-rail width and remaining viewport height, so all ten columns remain inside the app.
- Common portrait phones can keep both stacked harbours visible together; secondary battle copy is collapsed before the boards are allowed to overflow.
- Fleet Battle footer gives its full width to media, Chat and Leave game controls so messaging/actions are no longer clipped.

## v0.1.64 / 9.6.225

- Synchronized browser client to **9.6.225 / rantlist-deploy-r253** and protocol **63**.
- Drawing active tools preserve stroke-contrast backgrounds on dark themes.
- Fleet Battle mobile view stacks harbours, gives the local target a pulsing red border, compacts status/actions, and pins the footer.

## v0.1.63 / 9.6.224
- Synchronizes the attachment-tray and Drawing control-layout update from rantlist-deploy-r252.
- Attachment actions expand to fit complete labels instead of breaking words across lines.
- Drawing moves stroke style/width/dash controls to the bottom action toolbar, automatically contrasts stroke-driven tool previews, and labels **Back to chat** versus **Close and Exit**.
- Fresh profiles default the mobile Channel rail control to On while preserving an explicit Off preference.
- Browser source synchronized to rantlist-deploy-r252 / protocol 63.

## v0.1.62 / 9.6.223
- Synchronizes the attachment tray and Drawing readability update from rantlist-deploy-r251.
- Long attachment labels wrap inside their own cards; the first **Drawing** action uses the supplied `drawing1.svg` while **WebGL Draw** keeps its existing icon.
- Game/tool exits use the new visible amber exit treatment, and Drawing exposes Return + Close/Leave directly at the top-right instead of hiding them in an Actions menu.
- Drawing stroke controls wrap on smaller screens and the line-style preview remains visible against a neutral checker surface.
- Browser source synchronized to rantlist-deploy-r251 / protocol 63.

## v0.1.61 / 9.6.222
- Fix iOS Share Extension media delivery: the main app now streams App Group files to WKWebView in bounded chunks instead of relying on custom-scheme Fetch, preventing the observed **Load failed** send failure.
- Share sheet flow saves immediately and automatically attempts to open Rantlist; when iOS refuses to foreground the containing app, the extension shows only a concise saved-state message and Done.
- Pending share UI uses **Send item / Send N items**, and stale missing files are omitted instead of creating broken sends.
- Browser source synchronized to rantlist-deploy-r250 / protocol 63.

## v0.1.60 / 9.6.221
- Fix the inactive native **Shared items ready** bar so it is invisible unless a real Share Extension payload is queued.
- Keep the iOS notification permission prompt: it is required for APNs alerts/sounds and app-icon unread badges.
- After a successful iOS archive/export, automatically install and relaunch Rantlist on any connected/unlocked physical iOS development device; set `RANTLIST_IOS_INSTALL_CONNECTED=0` to disable this convenience.
- Share Extension remains provisioning-gated: automatic push-only fallback still applies until the App Group is assigned in Apple Developer.

## v0.1.59 / 9.6.220

- Fixes iOS release failure when the Apple Developer account has not yet assigned `group.fun.workwork.rantlist` to the app/Share Extension provisioning profiles.
- iOS release mode now defaults to `auto`: it tries the complete Share Extension build first, but if Apple rejects only the App Group entitlement it automatically retries a push-only archive. APNs registration and unread app-icon badges still ship.
- `RANTLIST_IOS_SHARE_MODE=full` requires the Share Extension and fails with an actionable provisioning message; `off` intentionally omits it.
- The real Share Extension remains in the project and will ship automatically once the App Group is registered and assigned to both iOS bundle identifiers.

## v0.1.58 / 9.6.220

- Adds native iOS APNs registration, notification/badge permission, foreground/tap handling and authenticated token handoff to the Rantlist server.
- Adds a real **Share to Rantlist** iOS Share Extension using the `group.fun.workwork.rantlist` App Group. Shared files, links and text remain queued until Rantlist is opened; navigate to the intended channel/private conversation and tap **Send here**.
- Adds Push Notifications + App Groups entitlements and embeds the Share Extension in the signed iOS archive.
- Browser source synchronized to rantlist-deploy-r248 / protocol 63.

## v0.1.55 / 9.6.90

- Adds native iOS app-icon and macOS Dock unread badges with Off / direct / all-channel modes.
- Adds the synchronized experimental image-AI UI for server-side Hetzner inference; client source contains no provider secret.
- Browser source synchronized to rantlist-deploy-r118 / protocol 63.

## v0.1.46 / 9.6.81

- Fixes native iOS **More chat space while typing on mobile** with a resilient composer-focus fallback and native-specific chrome-hiding selector.
- Browser source synchronized to rantlist-deploy-r109.

## v0.1.45 / 9.6.80

- Fixes iOS media Download so it stays in Rantlist and opens the native Files save-destination picker instead of replacing the chat UI with the raw media asset.
- Browser source remains synchronized to rantlist-deploy-r108.

## v0.1.33 / 9.6.71

- Fixes iOS image-editor Text mode keyboard dismissal during viewport resizing.
- Source synchronized to rantlist-deploy-r99.

## v0.1.32 / 9.6.70

- Adds a dedicated Rooms panel colour to Appearance themes.
- Adds an independent 60–140% media preview size control without changing text/control scale.
- Source synchronized to rantlist-deploy-r98.

## v0.1.31 / 9.6.69

- Adds optional borderless toolbar buttons and a separate general interface-border visibility toggle.
- Source synchronized to rantlist-deploy-r97.

## v0.1.29 / 9.6.68

Composer chrome cleanup: controls are vertically centered, while the outer message-form border/background is removed for a cleaner rounded input surface.

## v0.1.28 / 9.6.67

Native WKWebView confirmation dialogs are supported and media **Delete all** uses the r95 batch deletion flow.

## v0.1.27 / 9.6.66

Uploaded photo-gallery deletion now targets every message in the media batch and keeps the timeline consistent while those server deletions arrive.

# Rantlist Client

Public client-side source and native macOS, Android and iOS packaging for **Rantlist**.

- Rantlist: https://rantlist.me
- Project page: https://mojoworks.xyz/labs/rantlist/
- Publisher: **WORKWORK.FUN**

`web/` is a sanitized snapshot of the browser-side client. The production server, database, deployment configuration, mail/TURN configuration, payment secrets and private infrastructure are not included.

## Synchronize the public client

```bash
./scripts/sync_from_stage.sh
```

The source defaults to `/Users/smielniczuk/Documents/works/stage/chat`. The Rantlist application version in that source is the only marketing-version authority for the client.

## Test macOS build

```bash
./scripts/update_and_build_macos.sh
```

This creates an ad-hoc local tester build.

## Full signed release + GitHub + homepage

macOS remains the backwards-compatible default:

```bash
./scripts/release_and_deploy_homepage.sh
```

Choose one or more release targets:

```bash
./scripts/release_and_deploy_homepage.sh --platform macos
./scripts/release_and_deploy_homepage.sh --platform android
./scripts/release_and_deploy_homepage.sh --platform ios
./scripts/release_and_deploy_homepage.sh --platform macos,android
./scripts/release_and_deploy_homepage.sh --platform all
```

Shorthand flags `--macos`, `--android`, `--ios` and `--all` are also supported. No version argument is accepted: every platform uses the current verified Rantlist version from `stage/chat`, and one build number/tag covers the selected platform set. The workflow is resumable per platform, pushes the public source, creates one GitHub Release with the selected artifacts, and updates `https://mojoworks.xyz/labs/rantlist/`.

Artifacts:

- macOS: universal2 `.dmg` + `.zip`
- Android: signed `.apk` + `.aab`
- iOS/iPadOS: signed App Store-distribution `.ipa`

The supplied `assets/rantlist-logo.svg` is the source app logo; derived macOS/iOS/Android icon assets are included in the repository.

Android release signing requires a one-time local setup:

```bash
./scripts/setup_android_release.sh
```

The Android keystore stays under `~/.config/workwork/` and its password stays in macOS Keychain. iOS uses Xcode automatic signing for Apple team `5P9V78UZAC`; App Store/TestFlight publishing still requires the corresponding iOS/App Store configuration in Xcode/App Store Connect.

Preflight only:

```bash
./scripts/release_and_deploy_homepage.sh --platform all --preflight-only
```

Resume after a build/network/GitHub/SSH failure by running the same command again. See [RELEASE.md](RELEASE.md).

## Security model

The repository security scan rejects server/deployment files, payment/API token patterns, private keys, private IP addresses and explicit local service ports. Website SSH transport values are stored outside the repository in `~/.config/workwork/rantlist-release.env`; on the existing build Mac they are imported automatically from the local Cut release setup.


## macOS icon

The macOS app now uses the same icon artwork as the iOS app by default.


## iOS wrapper note

The iOS wrapper disables automatic WKWebView safe-area content insets to avoid duplicate bottom spacing under the mobile navigation.


## iOS keyboard stability

The iOS wrapper ignores SwiftUI keyboard safe-area resizing and leaves keyboard viewport handling to the web application, preventing double-resize bounce.


## v0.1.20 keyboard

The iOS wrapper uses normal native keyboard resizing; the web UI treats the resized WKWebView window as the single viewport source to avoid both bounce and blank keyboard space.


## v0.1.21 native iOS keyboard stability

The native iOS wrapper disables WKWebView bounce. While the keyboard is active, the web client does not mirror animated WebView resize frames back into CSS geometry; WKWebView is the single layout authority.


## macOS menu

The native macOS client includes a standard menu bar with About, website/help access, editing shortcuts, reload, hide and quit actions.


## Mobile typing space

Config → Controls includes an optional **More chat space while typing on mobile** setting. It hides the top bar and chat header only while the mobile message keyboard is open.

## Native startup and offline shell

The iOS, macOS and Android wrappers display a native Rantlist splash screen before the remote UI is available. If no validated internet connection is available, the wrapper displays a native offline message instead of an empty WebView. Connectivity is watched at the OS level; when the connection returns, the initial Rantlist URL is loaded again automatically if the browser UI had not yet completed its first successful load.
