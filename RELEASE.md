## v0.1.84 / 9.6.245

- Synchronized browser client to **9.6.245 / rantlist-deploy-r273** and protocol **63**.
- Reorganizes imported audio into a cover/metadata summary row, a full-width SVG waveform row, and a separate compact timing row.
- Keeps the performant single-path waveform renderer while removing the hard-to-read stroked timing overlay.
- Full-width waveform seeking remains available by pointer, drag and keyboard.

## v0.1.83 / 9.6.244

- Synchronized browser client to **9.6.244 / rantlist-deploy-r272** and protocol **63**.
- Reworks message and Media Library audio waveforms into a lightweight scalable SVG renderer with one clipped progress layer.
- Centers the current/total audio clock over the waveform without intercepting taps or drag-seek gestures.
- Refines Stories / Shorts action-rail positioning against the actually unobstructed vertical media lane.

## v0.1.82 / 9.6.243

- Synchronized browser client to **9.6.243 / rantlist-deploy-r271** and protocol **63**.
- Adds the explicit per-link yt-dlp chooser with quality/size estimates, live quota information and separate confirmations for sources over 3 and 7 hours.
- Expands the default long-media policy to a 24-hour ceiling while preserving server-side quota revalidation, reserved capacity and administrator-controlled limits.
- Adds fair per-identity scheduling across yt-dlp inspection/download/transcription, Translator, `/ai` and Image AI; Translator preserves valid same-user queued jobs while another translation is active, and `/ai` exposes queue/running state.

## v0.1.81 / 9.6.242

- Synchronized browser client to **9.6.242 / rantlist-deploy-r270** and protocol **63**.
- Improves inline/Stories video scrubbing with a visible custom range thumb and centers the Stories action rail.
- Adds self-profile storage usage/quota display backed by the server-authoritative per-identity upload quota.
- The default quota is 15 GiB, administrator-configurable (0 = unlimited), with concurrent in-flight reservations enforced server-side.

## v0.1.80 / 9.6.241

- Synchronized browser client to **9.6.241 / rantlist-deploy-r269** and protocol **63**.
- Adds a **Translate** action to completed Image AI/OCR result cards next to the existing Text and Markdown copy actions.
- Image AI output is normalized to plain text and routed through the existing Live Translator workflow, including provider/language controls, bounded translation batches and saved sessions with `image-ai` source provenance.

## v0.1.79 / 9.6.240

- Synchronized browser client to **9.6.240 / rantlist-deploy-r268** and protocol **63**.
- Removes the Stories photo-darkening shade and moves zoom/rotate/reset controls into the viewer top bar.
- Adds explicit mini-player Close, mini/full mutual visibility, a centered desktop full player and single-owner audio playback across chat tracks and Media Library.

## v0.1.78 / 9.6.239

- Synchronized browser client to **9.6.239 / rantlist-deploy-r267** and protocol **63**.
- Own channel-member avatar now opens self profile inspection with Edit/Done controls.
- Profile media can be removed from the public gallery without deleting the source chat message, while picture/status/bio editing continues through the existing validated Profile editor.

## v0.1.77 / 9.6.238

- Synchronized browser client to **9.6.238 / rantlist-deploy-r266** and protocol **63**.
- AI Slop Gallery cards now expose thumbnail render state and a direct retry action instead of silently showing an empty preview when the server-side Playwright derivative is missing.
- The server deployment now functionally smoke-tests the isolated Builder HTML thumbnail path as the production `www-data` user before activation, and missing saved previews self-heal after restart or Gallery open.

## Changes in v0.1.76

- Synchronized browser client to **9.6.237 / rantlist-deploy-r265** and protocol **63**.
- Keeps **Image AI** discoverable for supported images even when the local setting is Off, routing the action to the exact Config selector without changing the preference automatically.
- Moves the Image AI selector/timeout directly below the AI model and makes local mode versus server readiness explicit.

## Changes in v0.1.75

- Synchronized browser client to **9.6.236 / rantlist-deploy-r264** and protocol **63**.
- Added a live same-row Config preview for message-composer border treatments.
- Added responsive desktop side-inspector layout for Config and editable Profile without covering the chat workspace.

## Changes in v0.1.74

- Synchronized browser client to **9.6.235 / rantlist-deploy-r263** and protocol **63**.
- Adds a persistent Appearance control for composer-shell border treatments: slow glow, rotating accent gradient, rainbow orbit, fade, dashed, dotted, blinking amber and high-vis amber.
- All animated composer-border effects respect Reduced Motion while preserving a visible static border.
- Moves the persistent Media Library mini-player from the global top bar to the message viewport, reserving timeline clearance and simplifying the transport progressively on narrow screens.

## Changes in v0.1.73

- Synchronized browser client to **9.6.234 / rantlist-deploy-r262** and protocol **63**.
- Separates durable iOS direct/mention alert pushes from app-icon badge state so late alert delivery cannot reapply an already-read count.
- Badge snapshots are collapsible and non-stored, and foreground delivery forces an authoritative unread resynchronization instead of trusting stale APNs badge values.

## Changes in v0.1.72

- Synchronized browser client to **9.6.233 / rantlist-deploy-r261** and protocol **63**.
- Replaces the iOS Share Extension bridge page with a real native destination picker for Rantlist channels and people, so sharing completes from the system share sheet without reopening the app.
- Adds App Group session/destination caching for instant rendering plus a live ephemeral WebSocket refresh before Send is enabled; the share connection is isolated from normal presence and cannot replace the main app session.
- Text/link sends and file uploads wait for server-authoritative acknowledgements, while staged App Group data remains available only as recovery if a share is interrupted.

## Changes in v0.1.71

- Synchronized browser client to **9.6.232 / rantlist-deploy-r260** and protocol **63**.
- Replaces blind retries around GitHub Release creation with an explicit transaction: wait for exact tag/commit API visibility, create once, then reconcile remote state before any retry.
- If GitHub returns an ambiguous 5xx after committing the draft, the workflow reuses that draft instead of repeating the create request; a genuine pre-commit failure retries only after confirmed absence.
- Adds an offline mock regression verifier for post-commit 500 recovery, confirmed-absent retry and fail-closed indeterminate state, plus shell-syntax verification for the publication scripts.

## Changes in v0.1.70

- Synchronized browser client to **9.6.231 / rantlist-deploy-r259** and protocol **63**.
- Fixes missing iOS app-icon unread counts caused by a backgrounded WKWebView still being treated as actively viewing its current room while its WebSocket remained connected.
- Fresh native installs enable **Private + channel messages** badges by default, without overriding users who explicitly chose Off or Private-only.
- Adds native lifecycle and notification-permission diagnostics plus foreground authoritative badge resynchronization so APNs/provider or iOS Settings failures are visible.

## Changes in v0.1.69

- Synchronized browser client to **9.6.230 / rantlist-deploy-r258** and protocol **63**.
- Fleet Battle gives immediate visual acknowledgement to a fired cell, locks the other target cells until the authoritative response arrives, and then displays an explicit **HIT / MISS / SUNK** result.
- The final state now overlays the completed harbours with a clear winner statement, surviving fleet count, and the decisive sinking shot.
- Mobile board geometry remains the deterministic, square, two-board non-scrolling layout introduced in 9.6.229.

## Changes in v0.1.68

- Synchronized browser client to **9.6.229 / rantlist-deploy-r257** and protocol **63**.
- Replaces Fleet Battle's rendered-candidate binary search with deterministic mobile geometry budgeting, preventing the native iOS client from collapsing the boards to the old 18px floor.
- Both stacked harbours reserve their full panel chrome before sharing the remaining height, keeping every row and column visible at once with square cells and no board scrolling.
- WKWebView transient measurements now retry while preserving the usable first-paint grid instead of committing a tiny temporary result.

## Changes in v0.1.67

- Synchronized browser client to **9.6.228 / rantlist-deploy-r256** and protocol **63**.
- Mobile Fleet Battle fixes the elongated-board regression by defining the ten playable rows and columns from the same computed square cell size.
- The measured mobile fit now reduces both complete harbours together until they fit the visible stage; there is no mobile board-scroll fallback and row 10 remains visible.
- Fleet Battle can expand farther on desktop, while the in-app Development release entry now includes both deployment revision and authored summary.

## Changes in v0.1.66

- Synchronized browser client to **9.6.227 / rantlist-deploy-r255** and protocol **63**.
- Replaces Fleet Battle's hard-coded mobile height reserve with a measured fit pass driven by the actual stage and `ResizeObserver`; all harbour cells remain square and both stacked boards are reduced together until they fit.
- Adds an extreme-height vertical-scroll fallback so the lower rows stay reachable instead of being cropped behind the footer.
- Compacts the planning toolbar/title to one line in the normal state and enlarges active Fleet video surfaces from 40×26 to 64×36 CSS pixels.

## Changes in v0.1.65

- Synchronized browser client to **9.6.226 / rantlist-deploy-r254** and protocol **63**.
- Fleet Battle constrains every mobile battle container to the stage width left after the Channel rail and scales the 10×10 grids from width plus viewport height.
- Both harbours are height-bounded into two stacked rows for common portrait screens, with compact prompt/header chrome and no horizontal board overflow.
- Duplicate footer status is removed on mobile Fleet Battle, leaving complete room for media, Chat and Leave game controls.

## Changes in v0.1.64

- Synchronized browser client to **9.6.225 / rantlist-deploy-r253** and protocol **63**.
- Drawing stroke-driven tool controls remain legible while selected on dark themes.
- Fleet Battle mobile harbours stack vertically; the local harbour pulses red while under fire and the footer stays pinned with compact controls.

## Changes in v0.1.63

- Synchronized browser client to **9.6.224 / rantlist-deploy-r252** and protocol **63**.
- Attachment-tray actions use intrinsic width and `white-space: nowrap`, keeping complete labels such as Calendar, Drawing, WebGL Draw and Translator on one line.
- Drawing stroke controls move below the canvases into the bottom toolbar; stroke-driven tool buttons select a light/dark preview surface from the active stroke luminance so dark and light lines remain visible.
- Drawing session controls now visibly distinguish **Back to chat** from **Close and Exit**.
- New/fresh profiles start with the mobile Channel rail control enabled unless the user has explicitly saved Off.

## Changes in v0.1.62

- Synchronized browser client to **9.6.223 / rantlist-deploy-r251** and protocol **63**.
- Attachment-tray cards constrain and wrap long labels, and the first Drawing action uses `drawing1.svg` without changing the WebGL Draw icon.
- Session/game exit controls use a consistent amber emphasis at the existing size.
- Drawing removes `drawingActionSelect`, adds explicit opponent/return/leave controls, keeps those exits at the toolbar edge, wraps stroke ranges on narrow screens, and gives the line-style preview a contrast-safe checker surface.

## Changes in v0.1.61

- Replaces the unreliable `fetch(rantlist-share://...)` browser path with a native `rantlistShare` read request and bounded chunk callbacks (`rantlistNativeSharedFileChunk` / `rantlistNativeSharedFileError`). Shared photos/files are reconstructed as normal browser `File` objects and continue through the existing upload pipeline.
- The Share Extension persists the App Group manifest first, then automatically attempts `rantlist://share`; if iOS declines to open the containing app, the extension presents a single saved-state message rather than separate Open/Done commands.
- Missing App Group files are excluded from the pending payload so stale manifests cannot produce a broken Send action.
- Synchronized browser client to **9.6.222 / rantlist-deploy-r250** and protocol **63**.

## Changes in v0.1.60

- Native share pending UI now strictly respects `hidden`, eliminating the phantom **Shared items ready** card when no iOS share payload exists.
- iOS release builds now attempt a best-effort install + launch on connected physical development iPhones after the IPA is exported. Release publication still succeeds if no phone is connected or installation is unavailable.
- APNs notification permission remains intentional and required for native notifications and icon badges.

## Changes in v0.1.59

- Fixes the build-48 archive failure caused by stale/missing Apple App Group provisioning for `group.fun.workwork.rantlist`.
- `scripts/build_ios_release.sh` now supports `RANTLIST_IOS_SHARE_MODE=auto|full|off` (default `auto`). Auto mode first attempts the complete `RantlistShare` archive. If and only if Xcode reports an App Group entitlement/profile mismatch, the release creates a temporary project copy that removes the extension from the archive graph and removes App Groups while retaining the Push Notifications entitlement.
- The fallback does not mutate the checked-in Xcode project. It preserves APNs registration, server device-token handoff and unread app-icon badges, allowing the unattended watcher release to finish instead of failing the whole client release.
- To include **Share to Rantlist**, the Apple Developer account must register `group.fun.workwork.rantlist` and assign it to both `fun.workwork.rantlist` and `fun.workwork.rantlist.share`; after that, auto mode ships the extension normally. Use `RANTLIST_IOS_SHARE_MODE=full` to make missing Share provisioning fatal.

## Changes in v0.1.58

- Synchronized browser client to **9.6.220 / rantlist-deploy-r248** and protocol **63**.
- iOS requests alert/sound/badge notification permission, registers with APNs, forwards the device token only into the authenticated Rantlist session and applies authoritative server badge counts while foregrounded/backgrounded.
- The Xcode target enables Push Notifications and App Groups; debug builds identify sandbox APNs while release builds identify production APNs, with server-side endpoint recovery for mismatched development/distribution tokens.
- Adds an embedded **Share to Rantlist** Share Extension. Files/media/links/text are copied into an App Group inbox and handed to the main app; because iOS does not guarantee that a Share Extension can launch its containing app, the Open Rantlist action is best-effort and queued items remain available when the app is opened manually.
- In Rantlist, shared items show a persistent **Send here** bar; navigate to the desired channel or private conversation before sending.

## Changes in v0.1.57

- Android release builds now pin the Gradle runtime to JDK 17 even when a newer system Java (including Java 26) is first on PATH.
- Android Java discovery validates the actual runtime major and prefers the Homebrew openjdk@17 keg without changing the macOS-wide Java default.
- Android signing checks and keystore setup use the selected JDK 17 keytool explicitly.
- Android build output reports the exact JDK home/runtime before Gradle starts and fails early if it is not JDK 17.

## Changes in v0.1.56

- Synchronized browser client to **9.6.91 / rantlist-deploy-r119** and protocol **63**.
- Config → Media now puts **Experimental image AI** first, keeps the selector visible/selectable before the server key is configured, and shows explicit server readiness text.
- A missing Hetzner server secret no longer resets the saved AI preference to Off.

## Changes in v0.1.55

- Synchronized browser client to **9.6.90 / rantlist-deploy-r118** and protocol **63**.
- Config adds native unread app-icon badge modes: Off, private messages only, or private + channel messages. iOS updates the application icon badge and macOS updates the Dock badge while the app is running.
- Config → Media adds experimental server-side Hetzner image AI with On request / Automatic description modes, useful analysis presets and custom image questions.
- The Hetzner API key remains exclusively in the server secret environment; no API key is stored in the public/native client.

## Changes in v0.1.54

- Synchronized browser client to **9.6.89 / rantlist-deploy-r117** and protocol **62**.
- Audio files uploaded through drag and drop or the normal file picker now offer **Transcribe** from the message More menu, using the same transcription backend as recorded voice notes.
- Automatic voice-transcription mode also applies to uploaded audio attachments while keeping their original filename and file behavior.

## Changes in v0.1.53

- Synchronized browser client to **9.6.88 / rantlist-deploy-r116** and protocol **62**.
- Uploaded media keep **Share** and **Download** in the speech-bubble More menu even after Stories / Shorts snapshot data refreshes the same message state.
- Native iOS Download destination handling is unchanged.

## Changes in v0.1.52

- Synchronized browser client to **9.6.87 / rantlist-deploy-r115** and protocol **62**.
- Web link preview cards now default to 200% of their previous dimensions, making generated webpage screenshots much easier to see.
- Config → Controls adds a separate **Web link preview size** slider from **100–300%**; narrow mobile previews stack the screenshot above metadata.
- No native iOS/macOS behavior change in this client revision.

## Changes in v0.1.51

- Synchronized browser client to **9.6.86 / rantlist-deploy-r114** and protocol **62**.
- Server link-preview screenshots now support SwiftShader-backed WebGL/WebGPU rendering, reject blank black/white captures, and fall back to safe Open Graph/Twitter imagery when needed.
- No native iOS/macOS behavior change in this client revision.

## Changes in v0.1.50

- Synchronized browser client to **9.6.85 / rantlist-deploy-r113** and protocol **62**.
- Server deployments now automatically ensure a Chromium runtime for URL-preview screenshots; no manual Chromium installation or link-preview environment edit is required for the default Ubuntu production setup.
- No native iOS/macOS behavior change in this client revision.

## Changes in v0.1.49

- Synchronized browser client to **9.6.84 / rantlist-deploy-r112** and protocol **62**.
- Server deployment packaging now ignores stale staging `package-lock.json` files so the URL-preview `playwright-core` dependency can install during production activation.
- No native iOS/macOS behavior change in this client revision.

## Changes in v0.1.48

- Synchronized browser client to **9.6.83 / rantlist-deploy-r111** and protocol **62**.
- Text messages containing public web URLs can receive asynchronous rich preview cards with server-extracted title, description, hostname and a same-origin optimized screenshot thumbnail.
- Link-preview updates decorate the existing message bubble in place without delaying the original message or replacing its text.
- The message More menu adds **Open link** and **Copy link** actions; server-blocked/malicious destinations are not directly openable from the preview card.

## Changes in v0.1.47

- Synchronized browser client to **9.6.82 / rantlist-deploy-r110**.
- Small-screen modal dialogs are vertically centered instead of being forced to the bottom edge.
- Modal cards keep full rounded borders and safe-area spacing, with tall content scrolling inside the visible viewport.
- The **About this server** support panel is bounded away from the iOS home indicator so the Stripe fallback link remains reachable and visible.

## Changes in v0.1.46

- Synchronized browser client to **9.6.81 / rantlist-deploy-r109**.
- Fixed **More chat space while typing on mobile** in the native iOS app when WKWebView does not deliver the expected keyboard lifecycle callback sequence.
- Composer focus now has a native-only settled fallback, while normal UIKit `didShow`/`didHide` events still control the stable keyboard-transition path.
- Native iOS top-bar/chat-header hiding no longer depends on the browser responsive breakpoint.

## Changes in v0.1.45

- Native iOS media downloads no longer navigate the Rantlist WKWebView away from the chat UI.
- Download actions are handled by `WKDownload` and then open the iOS Files destination picker so the user can save the media to Downloads, iCloud Drive, On My iPhone/iPad, or another Files location.
- Server `?download=1` responses and attachment responses are forced into the native download path even for image/video MIME types that WebKit could otherwise display inline.

## Changes in v0.1.44

- Synchronized browser client to **9.6.80 / rantlist-deploy-r108**.
- Typing status now overlays the bottom of the message viewport instead of taking layout height, eliminating timeline shake when typing notifications appear or disappear.
- Jump-to-latest positioning accounts for the typing/context overlays without resizing the message list.

## Changes in v0.1.43

- Synchronized browser client to **9.6.79 / rantlist-deploy-r107**.
- Desktop camera-source choices always show concise Upload/Photo-video and Record/Webcam descriptions.
- Stories / Shorts now classifies mixed image/video feeds defensively, uses optimized still-image previews, and avoids loading a duplicate video stream for the blurred backdrop.
- Story video playback retries at `canplay`, while HLS remains preferred and downloads/editing retain original media.

## Changes in v0.1.42

- Synchronized browser client to **9.6.78 / rantlist-deploy-r106**.
- Media messages now use the existing speech-bubble Message actions button as the single More control.
- Share, Download and voice Transcribe moved into that menu; redundant image/video preview overlay buttons are removed.

## Changes in v0.1.41

- Synchronized browser client to **9.6.77 / rantlist-deploy-r105**.
- System messages are smaller, left-aligned and use zero outer spacing.
- Timeline media keeps preview/play visible while Share, Download and voice Transcribe move into a compact More menu.

## Changes in v0.1.40

- Synchronized browser client to **9.6.76 / rantlist-deploy-r104**.
- Fixed **More chat space while typing on mobile** in the native iOS client by retaining message-composer keyboard ownership across UIKit keyboard transitions.
- The top bar/chat header are hidden only after the native keyboard settles and are restored when it closes; other text fields do not trigger the mode.

## Changes in v0.1.39

- Synchronized browser client to **9.6.75 / rantlist-deploy-r103**.
- Direct-room badge avatars no longer open the profile overlay; clicking them now opens the direct conversation through the enclosing room badge.
- The current direct-channel badge remains inactive while already open.

## Changes in v0.1.38

- Fixed the release-source whitespace error that could stop the client release after macOS/iOS builds completed.
- Release preflight now checks tracked source whitespace before starting expensive signing/notarization/archive work.

## Changes in v0.1.37

- Added native startup splash screens for iOS, macOS and Android while the server-hosted UI is loading.
- Added a native **No internet connection** state with a clear request to reconnect and a manual **Try again** action.
- Native clients now watch connectivity and automatically reload `https://rantlist.me/` when internet access returns if the UI never finished loading, preventing a permanently blank/white WebView after an offline launch.
- Returning to the app also retries the initial UI load when needed, while an already-loaded UI is preserved across temporary network loss.

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
