## Changes in v0.1.36

- Synchronized browser client to **9.6.74 / rantlist-deploy-r102**.
- Removed the unrequested visible “Rooms” text from `roomRailToggleButton`.
- The optional room-rail control now matches the standard mobile navigation button sizing, spacing and active-state styling.
- Kept the composer fallback immediately left of `composerShell`.

## Changes in v0.1.35

- Synchronized browser client to **9.6.73 / rantlist-deploy-r101**.
- The active channel badge in the room rail is disabled so it cannot reload the current channel history.
- Added optional **Channel rail button in mobile controls** placement: first in `mobileNav`, with a left-of-composer fallback when that nav is hidden while composing.

## Changes in v0.1.34

- Synchronized browser client to **9.6.72 / rantlist-deploy-r100**.
- Improved the media-editor Date sticker so localized dates do not crop on mobile.
- Time/Date label stickers now use the existing text/background colour palette.
- Fixed caption input contrast on light themes.

## Changes in v0.1.33

- Synchronized browser client to **9.6.71 / rantlist-deploy-r99**.
- Image-editor Text mode on iOS now keeps its focused field mounted while the keyboard resizes the native WebView, so the keyboard remains open for typing.

## Changes in v0.1.32

- Synchronized browser client to **9.6.70 / rantlist-deploy-r98**.
- Added an independent **Rooms panel** Appearance colour token.
- Added a separate **Media preview size** slider in the Interface size popover and Config → Controls.
- Inline images, videos and media galleries can now be scaled from 60–140% independently of interface text and controls.

## Changes in v0.1.31

- Synchronized browser client to **9.6.69 / rantlist-deploy-r97**.
- Added Config > Controls toggles for borderless toolbar buttons and hidden general interface borders.
- Border preferences are local, reversible appearance settings.

## Changes in v0.1.30

- macOS native WKWebView now presents an `NSOpenPanel` for HTML file inputs.
- Profile picture selection and the other web file pickers now open the macOS file chooser inside the desktop app.

## Changes in v0.1.29

- Synchronized application version to **9.6.68 / rantlist-deploy-r96**.
- Vertically centered controls inside `composerShell`.
- Removed the `messageForm` top border and outer `.composer` background for cleaner composer chrome.

## Changes in v0.1.28

- Synchronized application version to **9.6.67 / rantlist-deploy-r95**.
- Fixed native iOS/macOS JavaScript confirmation dialogs, which prevented **Delete all** and other confirmed actions from proceeding in WKWebView.
- Multi-media **Delete all** now sends one validated batch deletion request instead of several independent requests.

## Changes in v0.1.27

- Synchronized application version to **9.6.66 / rantlist-deploy-r94**.
- Fixed **Delete all** for uploaded photo/media batches so every underlying server message is deleted instead of only the gallery's first item.
- Batch media now keeps per-item message metadata and removes one tile at a time as server deletion events arrive, preventing deleted galleries from reappearing after reload.

## Changes in v0.1.26

- Synchronized application version to **9.6.65 / rantlist-deploy-r93**.
- Newly posted images/videos now remain visible when their preview grows after processing or decoding.
- Bottom-follow is preserved only when the timeline was already at the newest message; deliberate scrolling cancels it.
- Native iOS defers media-follow while the keyboard itself is animating, avoiding another source of timeline shaking.

## Changes in v0.1.25

- Synchronized application version to **9.6.64 / rantlist-deploy-r92**.
- Added the optional **More chat space while typing on mobile** setting under Config → Controls.
- When enabled, the top bar and chat header hide only while composing with the mobile keyboard open.
- Native iOS waits until keyboard animation has completed before switching this focused layout.

## Changes in v0.1.24

- Added a native macOS menu bar with About Rantlist, Rantlist Website, Edit commands, Reload, Help, Hide and Quit.
- About Rantlist uses the standard macOS About panel and release metadata.

## Changes in v0.1.23

- Synchronized application version to **9.6.63 / rantlist-deploy-r91**.
- Native iOS now reports UIKit keyboard will/did show/hide lifecycle events to the web UI.
- Message bubbles are stabilized during keyboard animation by freezing timeline scrolling, disabling scroll anchoring and restoring the visible/bottom anchor once after completion.
- Native iOS keeps the mobile navigation layout stable during keyboard presentation to avoid a second reflow.

## Changes in v0.1.22

- Synchronized application version to **9.6.62 / rantlist-deploy-r90**.
- Restores one semantic patch increment for every delivered server deployment revision.
- Paired with the r90 version-progression verification guard.

## Changes in v0.1.21

- Removed the remaining iOS keyboard spring/jitter by preventing native WKWebView resize frames from feeding back into web layout geometry.
- Disabled WKWebView scroll bounce and directional overscroll in the native iOS wrapper.
- Native iOS keyboard mode now disables competing web transitions and uses dynamic viewport units instead of animated pixel height rewrites.
- Synced browser client to rantlist-deploy-r89.

## Changes in v0.1.20

- Fixed the large white gap above the software keyboard in the iOS app.
- Restored normal native WKWebView keyboard resizing and paired it with the r88 single-source viewport handling.
- Preserves the smoother r87 keyboard transition without double-applying keyboard height.

## Changes in v0.1.19

- iOS WKWebView now ignores SwiftUI keyboard safe-area resizing so the native wrapper and the web viewport do not both resize the UI during keyboard animation.
- Added a client regression check for the keyboard-safe-area behavior.

## Changes in v0.1.18

- iOS app no longer adds an extra bottom inset below the mobile navigation.
- Removed the dead empty space below mobileNav in the iOS wrapper.

## Changes in v0.1.17

- Fixed iOS/macOS native wrappers so embedded HTTPS content such as the Stripe Buy Button remains inside the About popup.
- External browser pages now open only after an explicit user click.
- Added verification for embedded-frame and user-activated external-navigation handling.

## Changes in v0.1.16

- macOS app icon now uses the same icon artwork as the iOS app.
- macOS release builder now defaults to the iOS 1024 AppIcon asset for consistent branding.

# Rantlist multi-platform release workflow

The release version is always mirrored from `/Users/smielniczuk/Documents/works/stage/chat`; no manual version argument is accepted.

## Platform selection

```bash
./scripts/release_and_deploy_homepage.sh                 # macOS only (default)
./scripts/release_and_deploy_homepage.sh --platform macos
./scripts/release_and_deploy_homepage.sh --platform android
./scripts/release_and_deploy_homepage.sh --platform ios
./scripts/release_and_deploy_homepage.sh --platform macos,android
./scripts/release_and_deploy_homepage.sh --platform all
```

`--macos`, `--android`, `--ios` and `--all` are shorthand equivalents.

A selected release shares one Rantlist source version, one monotonically increasing build number and one Git tag/GitHub Release. The state file records selected and already-built platforms, so a failure after one platform finishes can resume without rebuilding that platform.

## Outputs

macOS produces a Developer ID signed/notarized universal2 DMG, application ZIP and checksum file. Android produces a signed APK, Google Play AAB and checksum file. iOS/iPadOS produces an Xcode-signed App Store-distribution IPA and checksum file.

The common app logo source is `assets/rantlist-logo.svg`; platform icon assets are derived from that SVG.

## Android signing

Run once before the first Android release:

```bash
./scripts/setup_android_release.sh
```

The permanent release keystore is stored outside Git at `~/.config/workwork/rantlist-android-release.keystore`. Its password is stored in macOS Keychain. Back up the keystore securely because future Android upgrades must use the same signing key.

The Android builder expects Android SDK Platform 35 at `~/Library/Android/sdk` (or `ANDROID_SDK_ROOT`/`ANDROID_HOME`). Gradle is downloaded into the ignored `.android-build/` cache.

## iOS signing

The iOS project uses Xcode automatic signing with Apple team `5P9V78UZAC` by default. Override with `RANTLIST_APPLE_TEAM_ID` or `RANTLIST_IOS_BUNDLE_ID` if required. Xcode must have an Apple account/team capable of iOS App Store distribution. The generated IPA is suitable as an App Store distribution artifact; normal public iPhone/iPad installation should be through TestFlight or the App Store rather than direct GitHub sideloading.

## macOS media permissions

The macOS app has Hardened Runtime camera/audio-input entitlements plus camera/microphone usage descriptions. macOS still prompts the user on first media use. iOS and Android likewise use native camera/microphone permission handling for WebRTC calls.

## GitHub and homepage

After all selected platform builds pass checksums, the workflow commits/pushes the public client, creates an annotated tag `v<version>-b<build>`, creates a draft GitHub Release, uploads only the selected platform artifacts, and publishes it. The homepage deployment is pinned to that new release. If a platform is not present in the new release, the homepage keeps a download button for the newest earlier verified release that contains that platform.

## Resuming

The active state file is:

```text
release/.release-workflow-state.env
```

Run the same release command again after a failure. Inspect state with:

```bash
./scripts/release_and_deploy_homepage.sh --status
```

Preflight without building:

```bash
./scripts/release_and_deploy_homepage.sh --platform all --preflight-only
```

Abandon an incomplete workflow and allocate a new build number only when deliberately requested:

```bash
./scripts/release_and_deploy_homepage.sh --restart
```

## Website deployment profile

SSH host/port values remain outside the public repository in `~/.config/workwork/rantlist-release.env`, imported from the existing WORKWORK.FUN Cut deployment setup. The Rantlist homepage target is `https://mojoworks.xyz/labs/rantlist/`.

## Android SDK provisioning

Android releases target API 35. The release preflight now uses `sdkmanager` to install
`platforms;android-35`, `build-tools;35.0.0`, and `platform-tools` automatically when
those components are missing. Existing Android SDK licenses are respected; the script
does not silently accept new Android SDK license terms.
