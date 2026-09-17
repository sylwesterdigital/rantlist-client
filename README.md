## v0.1.100 / Rantlist 9.6.261
- Synchronizes browser/native clients with `rantlist-deploy-r289` / main protocol 70.
- Replaces the wide verbose media filename/size/MIME strip with a compact top-edge metadata chip that no longer obscures image/video previews.
- Voice memos default to **15 minutes** per device and Config → Speech can select **30 seconds, 1, 3, 5, 10, 15, 20 or 30 minutes**.
- Long voice recording prefers 64 kbps compressed MP4/WebM/Ogg; the server exposes a dedicated 30-minute / 32 MiB voice allowance without raising normal file limits.

## v0.1.99 / Rantlist 9.6.260
- Synchronizes browser/native clients with `rantlist-deploy-r288` / main protocol 70.
- Fixes iOS system sharing by removing the stale hard-coded browser `uiVersion`/`protocolVersion` from the Share Extension WebSocket URL.
- The Share Extension now connects with `clientRole=ios-share-extension&nativeShareProtocolVersion=1`; routine browser protocol/version releases no longer invalidate sharing.
- Client verification now fails if browser-version query parameters are reintroduced into `ShareViewController.swift`.

## v0.1.98 / Rantlist 9.6.259
- Synchronizes browser/native clients with `rantlist-deploy-r287` / protocol 70.
- Removes the browser `maxlength` that silently cut long `/ai` and `/ai build` instructions before send. Ordinary chat keeps its existing message-size limit, while selected OpenAI frontier models can receive a separately bounded prompt up to 256 KiB.
- Allows `/ai build` with no inline instruction when one or more explicit AI attachments are present, so `spec.md`, text/code, PDF or image files can be the complete build specification.
- Keeps the visible room command within the normal chat limit while the full large prompt remains transient to the authenticated AI request, and rejects oversized attached text before any paid inference instead of silently trimming it.

## v0.1.97 / Rantlist 9.6.258
- Synchronizes browser/native clients with `rantlist-deploy-r286` / protocol 69.
- Published AI-game deep links now always expose an app-owned **← Back to chat** control above the sandboxed game, including inside the iOS/macOS/Android shells.
- Returning from `/public/games/<uid>` explicitly loads the Rantlist root, so the user is not dependent on hidden browser history or native browser chrome.

## v0.1.96 / Rantlist 9.6.257
- Synchronizes browser/native clients with `rantlist-deploy-r285` / protocol 69.
- Adds the supplied AI Slop Gallery icon as the first Games tray destination, before Tic-Tac-Toe, so saved AI-built games are always directly reachable.
- Adds creator-only Publish/Unpublish controls for AI Builder games and public `/public/games/<uid>` links, with published generated code kept inside the server's opaque-origin network-disabled sandbox.

## v0.1.95 / Rantlist 9.6.256
- Synchronizes browser/native clients with `rantlist-deploy-r284` / protocol 68.
- Corrects OpenAI Builder failure reporting so a rejected page never claims that Rantlist automatically bought continuation/repair Responses.
- Keeps one explicit Builder command to one paid OpenAI Response and reports private token/cost usage even if executable-page validation rejects the result.
- Distinguishes paid-output-limit exhaustion from other invalid Builder HTML and gives the appropriate retry guidance.

## v0.1.94 / Rantlist 9.6.255
- Synchronizes browser/native clients with `rantlist-deploy-r283` / protocol 68.
- Expands user-controlled OpenAI paid output/reasoning limits to 1,024–128,000 tokens; fresh installs use 16,384 while existing saved choices remain unchanged.
- Separates long OpenAI answer retention from the older Hetzner text ceiling, preventing a provider-complete code/document response from being cut again locally.
- Marks `max_output_tokens` responses as partial: Copy/download contain every character returned by OpenAI, the status marker is excluded from the file, and partial filenames are explicit.
- Keeps one explicit command to at most one paid OpenAI Response; there is no automatic paid continuation.

## v0.1.93 / Rantlist 9.6.254
- Synchronizes browser/native clients with `rantlist-deploy-r282` / protocol 68.
- Keeps complete long AI answers in the message model while collapsing only their visual presentation; Show full output, Copy and Download .txt operate on the complete answer.
- Lets `/ai` commands carry a bounded batch of text, source-code, PDF and image attachments, including multimodal OpenAI BYOK input.
- Adds `/ai image <prompt>` for OpenAI BYOK and renders generated PNG output through the normal Rantlist protected media/medium-preview pipeline.
- Retains r281 paid-call guardrails, cancellation, secure Keychain/Keystore BYOK storage and fresh-install profile import/identity continuity.

## v0.1.92 / Rantlist 9.6.253
- Synchronizes the browser/native clients with `rantlist-deploy-r281` / protocol 67.
- Fixes OpenAI queue-status rendering and exposes cancellable long-running status without client error floods.
- Enforces the selected OpenAI paid output/reasoning token ceiling server-side and guarantees one explicit user command creates at most one paid OpenAI Response; GPT-6 Astra confirmation remains enabled by default.
- Keeps Import JSON available on a fresh install, restores exported UUID identity, and prevents a persisted nickname from silently becoming a second UUID.
- Retains Apple Keychain on iOS/macOS, Android Keystore-backed encryption, and page-memory-only browser OpenAI credentials.

## v0.1.90 / Rantlist 9.6.251
- Synchronizes the browser client with server 9.6.251 / `rantlist-deploy-r279` / protocol 65.
- OpenAI BYOK frontier requests use Responses background execution and status polling, with a 15-minute stock wait instead of the previous two-minute abort.
- The composer now receives terminal completed/failed queue events and clears “AI request running” after success or failure; running GPT-6 Astra requests show provider status and elapsed time.
- Existing Keychain/Android Keystore/browser-memory BYOK credential storage remains unchanged. Privacy mode uses `store:false` and a 9-minute polling cap; the explicit **Extended OpenAI jobs (>10 min)** per-device option uses `store:true` so OpenAI can retain/retrieve long-running background responses, with the provider-retention tradeoff shown in Config.

## v0.1.89 / Rantlist 9.6.250
- Synchronizes the browser client with server 9.6.250 / `rantlist-deploy-r278` / protocol 64.
- Moves iOS/macOS OpenAI BYOK credentials into Apple Keychain and Android credentials behind AES-GCM keys generated in Android Keystore; no OpenAI key is persisted in WebView `localStorage`.
- Ordinary browser BYOK is page-memory-only and legacy r277 localStorage keys are erased after one-time migration.
- Adds main-frame/origin restrictions, API-key diagnostic redaction and client verification guards for secure credential storage.

## v0.1.88 / Rantlist 9.6.249
- Synchronizes the browser client with server 9.6.249 / `rantlist-deploy-r277` / protocol 64.
- Adds per-user OpenAI BYOK configuration for GPT-6 Astra and GPT-5.6 Sol/Terra/Luna, with private per-call token/cost reporting and a resettable local spend estimate.
- No OpenAI credential is included in this public client package; every user supplies and controls their own key locally.
- Native release automation covers macOS, iOS and Android; the existing iOS build path installs/relaunches on connected development devices when available.

## v0.1.87 / 9.6.248

- Synchronized browser client to **9.6.248 / rantlist-deploy-r276** and protocol **63**.
- Restores the video seek thumb to a clearly visible 13 px size while keeping the full 22 px click/drag lane and borderless styling.
- Uses a tiny center highlight and soft shadow instead of the former heavy ring, with a slightly clearer 5 px progress track.
- Applies the same scrubber treatment to Stories video playback.

## v0.1.86 / 9.6.247

- Synchronized browser client to **9.6.247 / rantlist-deploy-r275** and protocol **63**.
- Channel-topic Leave, Share and Settings actions disappear whenever the current session cannot actually execute them instead of remaining as disabled controls.
- The empty channel-action group is removed from layout and the action handlers use the same availability contract.
- Video scrubbers keep their existing touch/drag lane but use a compact 6 px borderless visual thumb without the former high-contrast ring.

## v0.1.85 / 9.6.246

- Synchronized browser client to **9.6.246 / rantlist-deploy-r274** and protocol **63**.
- Imported audio artwork/play control is now a dedicated enlarged first column while title/detail, waveform and timing stay grouped in the adjacent body column.
- The SVG waveform keeps pointer/drag/keyboard seeking but naturally uses the remaining width beside the larger artwork.
- Completed collapsed transcripts are reduced to a compact **Transcript +** disclosure beside **Source**; the full transcript panel appears only when expanded.

## v0.1.84 / 9.6.245

- Synchronized browser client to **9.6.245 / rantlist-deploy-r273** and protocol **63**.
- Imported audio cards keep cover/play control and title/detail together in one compact first row.
- The SVG stripe waveform now uses the full audio-bubble width while preserving pointer, drag and keyboard seeking.
- Current/total playback time is restored to a small separate row below the waveform instead of being overlaid on the peaks.

## v0.1.83 / 9.6.244

- Synchronized browser client to **9.6.244 / rantlist-deploy-r272** and protocol **63**.
- Audio/voice playback time is centered over the waveform with a high-contrast pointer-transparent label, preventing right-edge clipping while keeping the full waveform seekable.
- Waveforms use a compact SVG path with a clipped played layer instead of dozens of per-peak DOM bars, reducing timeline and Media Library rendering work.
- Stories / Shorts right-side actions now center in the measured unobstructed lane between top controls and bottom metadata.

## v0.1.82 / 9.6.243

- Synchronized browser client to **9.6.243 / rantlist-deploy-r271** and protocol **63**.
- URL-only links supported by a site-specific yt-dlp extractor now open a centered per-link import chooser with encoding quality, estimated output size, source duration/extractor and the current profile storage quota before queueing.
- Imports above 3 hours require confirmation and imports above 7 hours require a second stronger confirmation; the server default ceiling is 24 hours with administrator-configurable byte/duration limits.
- yt-dlp inspection/download/transcription, Translator, `/ai` and Image AI use bounded fair multi-user scheduling so one profile cannot occupy every worker; accepted `/ai` jobs report queued/running state rather than appearing to fail silently.

## v0.1.81 / 9.6.242

- Synchronized browser client to **9.6.242 / rantlist-deploy-r270** and protocol **63**.
- Video preview timelines use a larger, always-visible high-contrast scrubber thumb without the browser-default black outline.
- Stories / Shorts action controls are centered vertically against the media viewport.
- Your own profile shows original upload storage usage and remaining quota. The server default is 15 GiB per identity, administrators can change it or choose unlimited, and concurrent uploads cannot bypass the limit.

## v0.1.80 / 9.6.241

- Synchronized browser client to **9.6.241 / rantlist-deploy-r269** and protocol **63**.
- Completed Image AI/OCR result cards now show **Translate** beside **Text** and **Markdown**.
- Translate hands the normalized plain-text result into the existing Live Translator, preserving its language controls, engines, batching and saved-session behavior.
- Saved Translator sessions retain `image-ai` provenance; no duplicate translation implementation was added.

## v0.1.79 / 9.6.240

- Synchronized browser client to **9.6.240 / rantlist-deploy-r268** and protocol **63**.
- Stories / Shorts no longer darkens photos with a full-height vertical gradient; image transform controls are centered inside the existing top bar.
- The persistent media mini-player now has a close control and is hidden whenever the expanded player is open.
- The desktop expanded player is centered, and minimizing it restores the mini-player.
- Inline chat audio/voice tracks and the persistent Media Library player are mutually exclusive, so starting one pauses the other.

## v0.1.78 / 9.6.239

- Synchronized browser client to **9.6.239 / rantlist-deploy-r267** and protocol **63**.
- Clicking your own avatar in the channel member rail now opens the same public profile view other authorized users see.
- A self-only Edit mode links to the existing Profile editor for picture/status/bio changes and adds non-destructive per-item profile-gallery removal.
- Removed gallery media stays in the original channel message/file; only profile visibility is changed server-side.

## v0.1.77 / 9.6.238

- Synchronized browser client to **9.6.238 / rantlist-deploy-r266** and protocol **63**.
- AI Slop Gallery cards now expose thumbnail render state and a direct retry action instead of silently showing an empty preview when the server-side Playwright derivative is missing.
- The server deployment now functionally smoke-tests the isolated Builder HTML thumbnail path as the production `www-data` user before activation, and missing saved previews self-heal after restart or Gallery open.

## v0.1.76 / 9.6.237

- Synchronized browser client to **9.6.237 / rantlist-deploy-r265** and protocol **63**.
- Supported image More menus always expose **Image AI**; when the per-device mode is Off, tapping it opens Config directly at the setting instead of silently hiding the action.
- Experimental image AI and its timeout now appear immediately below the AI model, with explicit per-device mode and server-readiness status.

## v0.1.75 / 9.6.236

- Synchronized browser client to **9.6.236 / rantlist-deploy-r264** and protocol **63**.
- Config now pairs the message-composer border selector with a live same-row preview.
- Wide desktop Config and editable Profile panels reserve a right-side inspector column so Chat, Users and Calls stay visible instead of being covered.
- Narrow/mobile behavior remains unchanged.

## v0.1.74 / 9.6.235

- Synchronized browser client to **9.6.235 / rantlist-deploy-r263** and protocol **63**.
- Appearance adds a persistent **Message composer border** selector with slow glow, rotating gradient, rainbow orbit, fade, dashed, dotted, blinking amber and high-vis amber options while retaining the normal theme border.
- Animated composer borders stop automatically under Reduced Motion without losing the selected static treatment.
- The persistent Media Library mini-player is removed from the crowded top bar and docked to the message viewport with reserved timeline space and compact mobile controls.

## v0.1.73 / 9.6.234

- Synchronized browser client to **9.6.234 / rantlist-deploy-r262** and protocol **63**.
- iOS direct/mention alerts no longer carry badge values; app-icon badge state is sent separately as collapsible, non-stored APNs snapshots.
- Foreground Rantlist notifications reject stale remote badge presentation and immediately resynchronize the server-authoritative unread total.

## v0.1.72 / 9.6.233

- Synchronized browser client to **9.6.233 / rantlist-deploy-r261** and protocol **63**.
- The iOS Share Extension now opens a native searchable **Channels / People** picker and sends directly to the selected Rantlist destination; the old “open the app to choose where to send it” bridge is removed from the normal flow.
- The host app caches only safe recipient/session metadata in the App Group for immediate picker rendering, and Send stays disabled until the extension refreshes authoritative destinations through its own ephemeral non-presence Rantlist connection.
- Shared text/links use the normal persisted message path and files reuse the existing validated chunk upload pipeline with explicit server acknowledgements; the old pending-share inbox is retained only for interrupted-share recovery.

## v0.1.71 / 9.6.232

- Synchronized browser client to **9.6.232 / rantlist-deploy-r260** and protocol **63**.
- GitHub Release creation is now transaction-safe: publication waits for the pushed tag to resolve through GitHub's API before creating a draft.
- An ambiguous HTTP 5xx/lost create response is reconciled by querying the remote release by tag; a second create POST happens only after the API confirms no release exists, preventing duplicate or untagged drafts.
- Recovered transient failures are logged as clean informational state reconciliation; indeterminate release state fails closed, and the offline verifier covers post-commit 500, confirmed-absent retry and API-indeterminate cases.

## v0.1.70 / 9.6.231

- Synchronized browser client to **9.6.231 / rantlist-deploy-r259** and protocol **63**.
- Fresh native installs default the app-icon unread badge to **Private + channel messages** while preserving an explicitly saved Off or Private-only preference.
- The iOS wrapper reports active/inactive/background lifecycle to the authenticated push bridge so a backgrounded WKWebView cannot make a channel look read and suppress unread counts or APNs.
- Returning to the foreground re-synchronizes the authoritative unread count; Config now reports iOS notification/Badge permission problems and whether the server says APNs delivery is ready.

## v0.1.69 / 9.6.230

- Synchronized browser client to **9.6.230 / rantlist-deploy-r258** and protocol **63**.
- Fleet Battle target taps now acknowledge immediately on the selected cell while the server-authoritative shot result is pending, preventing the iOS client from feeling dead after a tap.
- Resolved shots surface a temporary high-contrast **HIT / MISS / SUNK** banner, while the normal board marks remain authoritative.
- Finished Fleet matches now show a large winner overlay with **YOU WON** or the opponent name, surviving ship counts, and the final sinking coordinate/ship length.
- The 9.6.229 square two-harbour iOS fitting logic is retained unchanged.

## v0.1.68 / 9.6.229

- Synchronized browser client to **9.6.229 / rantlist-deploy-r257** and protocol **63**.
- Fixes the iOS Fleet Battle regression where the 9.6.228 binary-search fitter could collapse both harbours to miniature remnants after a transient WKWebView geometry read.
- Mobile harbour size is now calculated directly from the actual dual-board width/height and the combined heading/padding/border chrome of both panels; both complete 10×10 fields remain square and visible together without scrolling.
- Transient zero/tiny layout measurements are retried without replacing the conservative first-paint board, and Fleet cells explicitly clear inherited min/max heights so WebKit cannot stretch the square tracks.

## v0.1.67 / 9.6.228

- Synchronized browser client to **9.6.228 / rantlist-deploy-r256** and protocol **63**.
- Fleet Battle mobile harbours use explicit equal row/column tracks from one computed cell size, so every playable cell remains geometrically square instead of stretching vertically.
- Both complete 10×10 harbours shrink together to the real visible game-stage width and height and remain on screen simultaneously without a board/stage scrolling fallback.
- Desktop Fleet Battle uses a wider board host and no longer applies the old 430px harbour cap.
- The Development channel now receives and renders the release revision plus concise release summary together with the detailed changes.

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
