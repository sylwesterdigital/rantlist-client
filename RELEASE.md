## v0.1.152 — Tripo-native My Models previews

Synchronizes Rantlist **9.6.315 / r343**. My Models now uses Tripo's own rendered-image output instead of capturing screenshots from the live 3D stage. Compact/full model cards are larger image-first previews with overlaid metadata, hidden scrollbars and remembered desktop dragging. **Loading 3D stage…** reuses the channel typing rainbow animation while model replacement continues to preserve orbit, pan and zoom. Existing stored models and legacy previews remain compatible.

## v0.1.151 — demand-loaded media + lightweight Avatar Lab previews

Synchronizes Rantlist **9.6.314 / r342**. Hidden Avatar Lab image libraries no longer fetch full-resolution AI/source images; visible cards use lazy lightweight derivatives and originals load only for explicit full-size/profile/3D actions. Timeline video/HLS sources are deferred until playback, timeline hydration is limited to the nearby viewport and suspended while Avatar Lab or a hidden tab obscures chat. The compact media **source** links and SVG image previews from v0.1.150 are retained. No stored media/history/model data is deleted or migrated.

## v0.1.150 — compact source links + SVG image previews

Synchronizes Rantlist **9.6.313 / r341**. Imported media now shows a small clickable **source** link instead of the full `Source: https://…` URL. Dragged/dropped SVG files behave like images with an inline thumbnail and full-screen viewer; raw SVG remains download-only and the dedicated inline preview is sandboxed by the server. No stored user/profile/channel/message/media/model data is migrated.

## v0.1.149 — `/yt` merged-audio verification repair

Synchronizes Rantlist **9.6.312 / r340**. `/yt` no longer rejects a successfully merged video merely because yt-dlp's `.info.json` still describes a video-only source representation. The server verifies the completed downloaded container itself for an audio stream with ffprobe/ffmpeg before accepting or rejecting the import. Existing quality selection, limits, queueing and media-preservation behavior are unchanged.

## v0.1.148 — persistent 3D view + opt-in /yt video downloads

Synchronizes Rantlist **9.6.311 / r339**. Switching My Models now replaces only the loaded model and preserves the current Avatar Lab orbit, pan and zoom instead of snapping back to the default camera. Config → Media adds an off-by-default `/yt` video-download toggle; `/yt <URL>` uses the server-managed yt-dlp runtime, auto-selects the best bounded X/Twitter quality, and shows actual available resolution choices for YouTube, Odysee and other site-specific extractors. Downloads are bounded by server size/duration, queue and per-profile storage limits; existing media/history is never deleted to make room.

## v0.1.147 — persistent Avatar Lab and stable My Models order

Synchronizes Rantlist **9.6.310 / r338**. The docked Avatar Lab now remains open while typing in the channel, and its desktop backdrop no longer intercepts clicks on the chat side. My Models uses deterministic creation-time order, reconciles model snapshots by task ID, and preserves already known preview URLs so selection/status refreshes do not reshuffle cards or make previews disappear. No stored user/profile/channel/message/media/model data is migrated.

## v0.1.146 — Avatar Lab stage, model gallery and console lifecycle repair

Synchronizes Rantlist **9.6.309 / r337**. Focusing the channel Message composer now closes Avatar Lab/Avatar Maker, My Models reconciles stable cards instead of rebuilding thumbnails during polling, newly completed Tripo models carry authoritative selection state and load immediately into the single shared Three.js stage, and stage initialization is serialized to prevent competing WebGL renderers. Focus/`aria-hidden` handling, provider password forms and the trusted Helena iframe sandbox warning are also repaired. No stored user/profile/channel/message/media/model data is migrated.

## v0.1.145 — safe xAI TLS recovery

Synchronizes Rantlist **9.6.308 / r336**. xAI/Grok BYOK requests now recover from transient socket resets that occur before the TLS handshake completes: those provably unsubmitted requests may retry up to two times on fresh connections, with an IPv4 fallback first. Paid POSTs are still never automatically repeated after TLS is established or provider acceptance becomes ambiguous. Image AI shows a reconnecting phase during safe recovery, and xAI text chat now shares the hardened transport used by Grok Imagine image/video requests. No stored user/profile/channel/message/media data is migrated.


## v0.1.144 — existing-image conversion in Image AI

Synchronizes Rantlist **9.6.307 / r335**. Open any stored chat image and choose **Image AI → Convert / edit image** to use that exact image as the source. The dialog now exposes **GPT-6 Astra · OpenAI**, **Grok Imagine 2.0 · xAI**, and **Grok Imagine 1.0 · xAI** when the matching BYOK key is available, with conversion presets plus a custom prompt. The generated image is posted as new protected media; the source remains unchanged. `/ai help` documents this actual flow and no longer tells users to attach an image to a command in the composer.

## v0.1.143 — Astra reference-image editing in `/ai`

Synchronizes Rantlist **9.6.306 / r334**. `/ai image` can now use the exact image attachments queued with the command as GPT Image edit/reference inputs. The selected OpenAI mainline model remains user-controlled; selecting GPT-6 Astra enables the requested Astra-directed flow without silently changing models. `/ai help` and the composer attachment notice explain the order: type the command, attach image(s), then send. Text-only image generation remains unchanged and all output continues through normal protected Rantlist media.

## v0.1.142 — Tripo texture v3.5

Synchronizes Rantlist **9.6.305 / r333**. Avatar Lab 3D settings now expose Tripo texture model `v3.5-20260815` independently from the geometry model, with v3.5 used by default for new sessions. Fast/Standard/Detailed/Extreme texture quality is available; Fast automatically pins v3.5. Existing saved provider settings and model history remain compatible.

## v0.1.141 — bitmap model previews + iOS Avatar Lab repair

Synchronizes Rantlist **9.6.304 / r332**. Avatar Lab model cards now display persisted JPEG bitmaps captured from the single visible 3D stage; the gallery creates no WebGL renderers. The stage renderer is reused across model changes and close/reopen cycles, pausing while hidden to avoid iOS/Safari context-budget churn. Mobile/iOS uses a dedicated full-screen stage-first layout with compact Source/Reference cards, settings sheets, Style bottom sheet, collapsed model drawer and a scrollable prompt workspace. No destructive profile/media/model migration.

## v0.1.131 — deployment CSP verification repair

Synchronizes Rantlist **9.6.294 / r322** after the r321 server was activated successfully but its final transport probe falsely rejected the valid `connect-src 'self' blob: wss:` header. The server verifier is corrected without weakening WSS enforcement; the client snapshot/version metadata is advanced so the normal release workflow remains synchronized. No user data model changes.

## v0.1.130 — image-first Avatar Lab cards + safer Tripo recovery

Synchronizes Rantlist 9.6.293 / r321. Avatar Lab now treats Source and Reference as image surfaces first, overlays compact controls instead of shrinking the media, defaults fresh reference renders to 1:1, enlarges dropdown chevrons, and makes body-part selection visibly interactive. The server-side Tripo flow switches to the documented V2 `/upload` multipart endpoint, retries only the non-billable upload stage on transient gateway failures, and returns clean trace-aware diagnostics without risking duplicate billed task creation. No destructive profile or media migration is introduced.

## v0.1.129 — fixed Avatar Lab workbench + precision reference controls

Synchronizes Rantlist 9.6.292 / r320. Avatar Lab restores compact xAI reference settings in the fixed workbench, gives the body editor substantially more space, places Render reference with the source controls, remembers provider settings per profile, and makes paid work visibly progress through Prepare → Send → Generate → Save. Empty/activity overlays obey their actual state and stale 3D loader failures can no longer hide a newer loaded model. No destructive profile or media migration is introduced.

## v0.1.128 — compact Avatar Lab + interactive body styling

Synchronizes Rantlist 9.6.291 / r319. The Avatar Lab overlay now uses a compact flow header, fixed visual workbench and independently scrollable prompt/customization deck. Generated image/video media no longer reserves duplicate hidden space; webcam source capture, Profile shortcut, clickable body-part styling, transient provider activity, explicit disabled-action reasons and correctly stacked full 3D controls are included. Server generation starts accept normalized source images through the bounded Avatar Lab envelope instead of failing at the generic control-message limit. No destructive profile or media migration is introduced.

## v0.1.127 — guided Avatar Lab progress + reliable 3D preview

Synchronizes Rantlist 9.6.290 / r318. The Avatar Lab overlay now makes the three-step generation path explicit, keeps advanced selectors out of the primary workflow, gives image and 3D render actions prominent placement, preserves portrait output proportions, shows active request/progress/error state, reports generation cost/balance where providers expose it, and fixes embedded GLB texture preview loading. Existing user/profile/channel/media compatibility remains unchanged.

## v0.1.126 — standalone Avatar Lab workbench + reusable prompts

Synchronizes Rantlist 9.6.289 / r317. Avatar Lab is launched from the Games tray instead of living inside Profile. The desktop workbench keeps source, generated concept and 3D stage together, adds rig-ready/custom selector-composed prompts and reusable generation metadata, while preserving existing profile/user compatibility.

## v0.1.125 — integrated Avatar Suite wizard

Synchronizes Rantlist 9.6.288 / r316. Profile Avatar Lab now guides the user from a webcam/uploaded headshot through an editable Grok full-body concept and into a detailed textured Tripo3D avatar, with clothing/body configuration and responsive controls.

## v0.1.124 — compact Avatar Lab render controls

Synchronizes Rantlist 9.6.287 / r315. Grok and Tripo render actions remain visibly labelled with icons and stay in the same compact row as their settings where the Profile drawer has enough width; narrow screens still wrap safely.

## v0.1.123 — responsive Profile layout

Synchronizes Rantlist 9.6.286 / r314. Profile sections now stay inside the visible drawer at tablet/narrow-desktop sizes and enlarged accessibility text. Avatar Lab controls reflow into compact rows instead of being cropped horizontally.

## v0.1.122 — Grok chat + controllable 3D avatar preview

Synchronizes Rantlist 9.6.285 / r313. A configured xAI/Grok key can now be used for normal `/ai` text chat through selectable Grok models. Avatar Lab keeps explicit prompt-driven profile-image editing, and the 3D preview adds stage/floor colour controls, brighter adjustable lighting and Front / Portrait / Full body views.

## v0.1.121 — working xAI/Grok Avatar Lab

Synchronizes Rantlist 9.6.284 / r312. The configured user-owned xAI/Grok key now powers explicit Avatar Lab image editing and video generation from the profile image. Generated Grok images can be selected as the profile photo or used as the Tripo3D source; provider keys remain protected by native secure storage or page-memory-only browser storage.

## v0.1.120 — production builder safety sync

Synchronizes Rantlist 9.6.283 / r311. No client UX change: this release follows the server packaging fix that preserves importmap/JSON script data during production transforms and makes the production browser build a deployment-preflight check.

## v0.1.119 — working Avatar Lab and creative BYOK

Synchronizes Rantlist 9.6.282 / r310. Profile Avatar Lab now runs user-authorized Tripo3D generation from the current profile image, stores completed GLBs under Rantlist control and previews them interactively with WebXR when available. Config adds Tripo3D and xAI/Grok BYOK; native apps protect provider keys in Keychain/Android Keystore while browser mode keeps them only in page memory. The old Coming next roadmap card is removed.

## v0.1.118 / Rantlist 9.6.281
- Synchronizes native clients with canonical server UI `rantlist-deploy-r309` / protocol 70.
- Keeps the **Coming next / Avatar lab** roadmap visible on the Welcome back surface instead of leaving it behind in the hidden full profile drawer.
- Adds `NOTES-AVATAR-LAB.md` preserving the supplied Flask/i2i Tripo3D → local GLB → WebXR → Stage implementation target.

## v0.1.117 / Rantlist 9.6.280
- Synchronizes native clients with canonical server UI `rantlist-deploy-r308` / protocol 70.
- Native iOS now hides the non-working embedded Stripe Buy Button in **About this server** and promotes the configured direct Stripe payment link to the primary support button.
- Browser clients keep the embedded Stripe Buy Button with the direct payment URL as fallback.

## v0.1.116 / Rantlist 9.6.279
- Synchronizes native clients with canonical server UI `rantlist-deploy-r307` / protocol 70.
- Anonymous or session-replaced saved profiles now open directly on the explanatory **Welcome back** surface instead of exposing an empty workspace.
- Enlarges the Welcome back avatar, moves the profile colour and clear-name minus control beside Nickname, keeps **Enter user** disabled while Nickname is empty, and reduces administrator entry to a compact corner lock button.
- Includes `DEVELOPMENT-SAFETY.md` so the data-preservation incident and release-safety contract travel with both server and client source packages.

## v0.1.115 / Rantlist 9.6.274
- Synchronizes native clients with canonical server UI `rantlist-deploy-r302` / protocol 70.
- Restores the missing r298-r300 Development release entries and carries the durable, revision-keyed Development history behavior into the native web snapshot.
- No native permission, entitlement or platform-specific dependency change.

## v0.1.114 / Rantlist 9.6.273
- Synchronizes native clients with canonical server UI `rantlist-deploy-r301` / protocol 70.
- Profile **Use camera** now opens a real live webcam preview and captures a still image instead of invoking another file chooser.
- Adds a dedicated saved-profile minus/remove control beside **New profile**, keeping avatar-picture removal separate from identity deletion.
- Deleting a saved identity resets the editor to a blank new profile and leaves entry disabled until a nickname is supplied or another saved identity is explicitly chosen.

## v0.1.113 / Rantlist 9.6.272
- Synchronizes native clients with canonical server UI `rantlist-deploy-r300` / protocol 70.
- Deleting the final saved identity now clears the onboarding editor and consumed legacy migration state instead of allowing stale profile data to reappear.
- `Save and enter` / `Enter user` stay disabled until a nickname is present, with explicit nickname validation as a second guard.
- The existing administrator login control is available from the initial full-screen entrance and returns to the normal profile drawer after sign-in.

## v0.1.112 / Rantlist 9.6.271
- Synchronizes the native clients with canonical server UI `rantlist-deploy-r299` / protocol 70.
- Anonymous startup is now one full-screen start/return identity surface; disabled rooms/chat/users/calls and the normal profile drawer stay out of view until entry.
- Reuses the real profile start card for nickname, photo upload and front-camera capture, and places saved identities plus JSON restore on the same entrance.
- Entry buttons render a single `Save and enter` / `Enter user` label instead of duplicate normalized labels.

## v0.1.109 / Rantlist 9.6.268
- Synchronizes to server `rantlist-deploy-r296` / protocol 70.
- Restores HLS creation for capped profiles by preserving FFmpeg's required escaped comma in `min(height,ih)`, and surfaces terminal source-video fallback if optimization fails.
- Moves the opt-in per-upload quality chooser to the common ordinary-video upload boundary so all browser/native-WebView attachment routes honor it.
- Extends the same preference to the iOS Share Extension, which asks for the HLS preset before directly sending a shared video. Original masters are retained unchanged.

## v0.1.108 / Rantlist 9.6.267
- Completes the iOS live screenshot/editor Share Extension path by adding data/file-representation fallback when `loadObject(UIImage.self)` is advertised but fails.
- Unwraps UIKit `NSKeyedArchiver` image payloads and persists the embedded PNG/JPEG bytes with the correct image MIME type instead of rejecting the share or uploading the plist wrapper.
- Generic data/content representations can no longer pre-empt an advertised image representation.

## v0.1.107 / Rantlist 9.6.267
- Fixes iOS Share Extension uploads from the system screenshot/editor flow that expose an abstract `com.apple.uikit.image` item before a concrete JPEG/PNG representation.
- Concrete image UTTypes with real MIME types are preferred; abstract UIKit image objects are decoded and written as actual PNG/JPEG bytes instead of copying the `NSKeyedArchiver` plist wrapper as `application/octet-stream`.
- Adds client verification guards so future Share Extension changes cannot silently reintroduce the archived-UIImage upload path.

## v0.1.106 / Rantlist 9.6.267
- Synchronizes browser/native clients with `rantlist-deploy-r295` / main protocol 70.
- Adds the opt-in Config → Media **Ask video quality before upload** flag; Video and generic File pickers prompt before sending selected video bytes.
- Offers Maximum, High, Balanced and Data saver HLS presets. Maximum/High preserve source resolution/FPS, while the original uploaded master remains unchanged for download/fallback.
- The flag is off by default, so existing user behavior and the administrator media profile remain unchanged until explicitly enabled.

## v0.1.105 / Rantlist 9.6.266
- Synchronizes browser/native clients with `rantlist-deploy-r294` / main protocol 70.
- Built directly from the restored r288 client baseline; r289-r293 changes are intentionally skipped.
- Voice memos default to 15 minutes; Config → Speech allows 30 seconds, 1, 3, 5, 10, 15, 20 or 30 minutes.
- Uses the dedicated server-advertised voice-message size ceiling without changing ordinary file/video limits.

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
- Corrects the over-reduced r275 video scrubber: 13 px visible thumb, 22 px interaction lane, borderless center-highlight treatment, and a 5 px progress rail.
- Keeps track-click seeking, drag seeking, keyboard control and Stories parity unchanged.

## v0.1.86 / 9.6.247

- Synchronized browser client to **9.6.247 / rantlist-deploy-r275** and protocol **63**.
- Hides unavailable channel-topic Leave, Share and Settings controls, including the action group when it has no executable actions.
- Keeps matching handler guards so hidden actions cannot be invoked after permissions/connectivity change.
- Reduces the video seek thumb from 18 px to 6 px, removes outline/ring styling and preserves the full range-input interaction area.

## v0.1.85 / 9.6.246

- Synchronized browser client to **9.6.246 / rantlist-deploy-r274** and protocol **63**.
- Gives imported audio artwork/playback a responsive 94–112 px first column and moves title/detail into `voice-note-body` above the waveform.
- Preserves the single-SVG waveform renderer, separate current/total timing and all existing seek interactions.
- Collapses completed transcripts into a lightweight inline disclosure on the Source metadata row instead of a shaded transcript rectangle.

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
