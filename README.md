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
