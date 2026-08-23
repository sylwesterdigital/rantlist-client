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
