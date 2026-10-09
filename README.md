## Call Doctor media diagnostics — client 0.1.314 / server 9.6.530 / r558

## Watcher all-platform release target fix — client 0.1.313 / server 9.6.529 / r557

The selected-vehicle controls now use stable UI drafts and merge each changed field into the current authoritative vehicle state. Continuous tuning, effects, audio, condition and related controls are coalesced before a compact shared update, so controls such as sample ground colour no longer reset unrelated dust settings and the final values propagate consistently to connected clients.

## Stage permission roster, player capacity + mobile hydration — client 0.1.309 / server 9.6.523 / r551

Channel World permissions now show profile avatars without exposed UUIDs, owners can set a per-channel Stage capacity (8 players by default), permission changes are surfaced to affected users, and view-only edit attempts identify the owner to ask for access. Mobile/WebView Stage entry now waits for an authoritative server join response and retries instead of treating a sent join packet as a completed join, preventing blank private-looking Stage sessions after an early join race.

## Channel-owned authoritative Stage realms — client 0.1.308 / server 9.6.522 / r550

Each Rantlist channel now exposes one server-authoritative Stage realm. Channel creators are Full Ownership by default; non-owners are view-only until granted Can Edit or Full Ownership. Channel World checkpoints, restore/export, permission controls, realm-generation reconnect safety, and viewer fail-closed resynchronization are included in the bundled web client. Personal preset imports remain local copies until an authorized owner explicitly restores one into the channel.

## Stage bookmark capture + chat teleport — client 0.1.307 / server 9.6.519 / r547

The bundled web client renders shared Stage bookmark screenshots with a compact `Teleport` action and carries the r547 bookmark payload/camera pose contract. Native packaging is otherwise unchanged.

## PICO Web App release integration — client 0.1.306

PICO is now a first-class Rantlist release target. `--platform pico` validates the hosted `https://rantlist.me/` PWA and manifest, creates a versioned PICO Web App submission/audit bundle for GitHub Releases, and updates the project homepage with a **PICO Web App** entry. PICO's store path is URL-based Web App/PWA distribution rather than an APK/AAB build, so the PICO target deliberately does not reuse the Meta Quest Bubblewrap package. `--platform all` now covers macOS, Android, Meta Quest, PICO, iOS, Windows and Linux. This integration package targets only PICO through the watcher so existing native clients are not rebuilt unnecessarily.

## 0.1.303 / server 9.6.516 / r544

Quest XR runtime repair: restore `com.meta.androidbrowserhelper:androidbrowserhelper:2.5.0`, the Meta Quest TWA helper used by the known-good 0.1.282/r536 client. Keep the 2D Horizon app mode, the `com.google.androidbrowserhelper.trusted.LauncherActivity` manifest entry supplied by the fork, Quest-only watcher release targeting, automatic ADB reinstall, and automatic launch. The generic Google helper introduced during the launch-hotfix sequence is removed so the installed Quest app again uses Meta's Quest-specific TWA runtime for in-page WebXR.

## 0.1.301 / server 9.6.516 / r544

- Quest-only hotfix releases no longer build Android, iOS, macOS, Windows, or Linux when the watcher invokes the general `--platform all` workflow; this package carries a one-package Quest release target and the release workflow narrows to Quest automatically.
- Fixes Quest ADB discovery for real `adb devices -l` output that may use spaces rather than a tab between serial and state.
- A connected authorised Quest is reinstalled and launched immediately after the Quest APK is verified.

## 0.1.300 / server 9.6.516 / r544

- Fixes Quest USB detection in the automatic installer: the release script previously disabled space splitting globally, then parsed `adb devices` output with space-separated fields, so an attached Quest could be incorrectly reported as absent.
- Quest auto-install now parses native tab-delimited `adb devices -l` output, recognizes Meta/Oculus/Quest metadata, reinstalls the APK, and launches the declared TWA activity explicitly.
- Connected-but-unauthorised or unrecognized USB devices now produce explicit red errors instead of a generic warning.

## 0.1.299 / server 9.6.516 / r544

- Fixes the Quest auto-install function declaration: 0.1.298 accidentally shipped a literal `\n` before `install_connected_quest_devices`, so the build succeeded but the install function was never defined.
- The normal Quest release now reaches the connected-device install/launch step after APK/AAB verification.
- Adds a regression test that executes the extracted install function with installation disabled, catching malformed function declarations that `bash -n` alone does not catch.

## 0.1.298 / server 9.6.516 / r544

- Fixes the Quest APK launch-class verification itself: the previous `grep -q` pipeline ran under `pipefail`, so a valid match could still be reported as failure when upstream received SIGPIPE.
- Quest APK verification now inspects every `classes*.dex` entry without an early-closing pipeline and still fails closed if `LauncherActivity` is genuinely absent.
- Keeps the standard Android Browser Helper 2.5.0 Quest TWA change from 0.1.296; normal Android remains separate.

## 0.1.296 / server 9.6.516 / r544

- Quest launch repair: use the Android Browser Helper artifact that actually packages `com.google.androidbrowserhelper.trusted.LauncherActivity`.
- Quest release now inspects the built APK DEX and refuses publication if the launcher class is missing.
- Keeps the Quest app as a 2D TWA so Stage can request `immersive-vr` directly from the browser-backed session.

## 0.1.295 / server 9.6.516 / r544

- Release storage checks now print explicit red low-storage/stop banners with the exact location, available space, and required minimum.
- Local macOS storage is checked before remote desktop-worker preflight so a local shortage is immediately identifiable.
- Ubuntu desktop-worker storage failures now report the worker build root, available space, and 5 GiB requirement in red.

## 0.1.294 / server 9.6.516 / r544

- Release preflight now clears only stale project-local build intermediates before judging local disk space.
- The old unconditional 2 GB preflight stop is replaced by a hard 512 MB safety floor plus a warning below 2 GB; each local platform build cleans its own temporary output after verified artifacts are copied to `release/`.
- The r544 Quest verifier is release-forward for later client package hotfixes.

## 0.1.293 / server 9.6.516 / r544

- Restores the proven hand-written Meta Quest 2D Trusted Web Activity from the working 0.1.282 architecture.
- Quest uses `com.meta.androidbrowserhelper:androidbrowserhelper:2.5.0` and `LauncherActivity`; Enter VR stays inside the Quest Browser-backed app and calls WebXR directly.
- Removes the Bubblewrap XR bridge/custom-tab build path from the active Quest release.
- Normal Android phone/tablet remains the existing native WebView app.
- Homepage verification now accepts operator-owned showcase content instead of requiring the packaged empty bootstrap file.

## 0.1.292 / server 9.6.515 / r543

- Preserves operator-edited `homepage/content.json` across client ZIP synchronization and normal release preparation.
- Normal homepage releases now publish that exact local operator file and verify the public copy matches it.
- Homepage release notes are generated from the same server `DEVELOPMENT_RELEASES` chain used by Rantlist `#development`.
- Packaged showcase bootstrap content is disabled and empty, so a fresh checkout cannot replace operator media with a fake default clip.

## 0.1.291 / server 9.6.514 / r542

- Pairs with server r542.
- Quest XR bridge runtime is unchanged; this client bump aligns release metadata with the historical verifier-only server repair.

## 0.1.290 / server 9.6.513 / r541

- Pairs with server r541.
- Quest XR bridge behavior is unchanged from 0.1.289; this client bump keeps release metadata aligned with the verifier-only server repair.

## 0.1.289 / server 9.6.512 / r540

- Pairs with server r540; Quest bridge behavior is unchanged from 0.1.288.
- Release metadata advances so the one-shot watcher processes this client after the r539 server verification failure.

## 0.1.288 / server 9.6.511 / r539

- Keeps the r538 Quest Bubblewrap + immersive XR bridge runtime unchanged.
- Pairs with server r539, whose watcher supports `--once` and whose historical r468 verifier accepts the Quest fallback-aware Enter VR path.
- Normal Android phone and Quest artifacts remain separate.

## 0.1.287 / server 9.6.510 / r538

Quest keeps the Bubblewrap 2D PWA as the normal launch surface. The generated Quest project now receives a same-package `XRBridgeActivity`; Stage Enter VR uses that bridge when the 2D PWA reports `immersive-vr` unsupported, opening only validated `rantlist.me/stage` URLs through Meta Browser `WebXRCustomTabActivity`. Ordinary Android remains unchanged.

## 0.1.286 / server 9.6.509 / r537

Quest Bubblewrap now uses the synthetic SDK layout that Meta Bubblewrap 1.24.1 accepts, while also making that exact same path the sole Gradle SDK root. ANDROID_SDK_ROOT is removed and ANDROID_HOME is pinned to the Bubblewrap SDK before generation/build. This fixes both prior failures: 0.1.284 reached Gradle with conflicting SDK roots, while 0.1.285 pointed Bubblewrap at an Android Studio SDK layout that its own validator rejected.
Meta Quest is now built by the published `@meta-quest/bubblewrap-cli` from `https://rantlist.me/manifest.webmanifest`; the retired hand-written Quest Gradle/TWA wrapper is removed. Android phones keep the native WebView APK. Quest remains a separate APK/AAB and the release transaction publishes dedicated Android and Meta Quest downloads. Generated Bubblewrap output is isolated under `.quest-bubblewrap-build` so it cannot contaminate later ZIP synchronization.

## 0.1.282 / release integration

Android phone and Meta Quest remain separate artifacts, and the release transaction now understands both. `--platform android,quest` builds, verifies, publishes both APK/AAB pairs to the same GitHub release, then deploys homepage download links including a dedicated Meta Quest APK button. The normal general release now includes Quest alongside macOS, Android, iOS, Windows and Linux; Android/Quest/iOS build before the potentially slow macOS notarization step.

## 0.1.280 / server 9.6.508 / r536

Quest now runs the normal Rantlist 2D app surface as a verified Trusted Web Activity backed by Meta Quest Browser rather than Android WebView. The Stage `Open XR` action therefore calls WebXR directly inside the installed app and no longer launches a visible standalone Browser window. Ordinary Android phones keep the existing native WebView, secure credential, share-target and download bridges. The paired r536 server publishes Digital Asset Links for `fun.workwork.rantlist`; r534 Quest low-memory rendering and the r535 Stage startup-order fix are retained.

## 0.1.279 / server 9.6.506 / r534

Quest/headset Stage startup now uses a conservative WebXR profile (no MSAA/preserveDrawingBuffer, DPR <= 1, XR framebuffer scale 0.50) plus a lil-gui safe-session/diagnostic panel. The Quest Android APK is explicitly declared as a supported 2D headset panel and keeps XR actionable through a trusted external-browser handoff when Android WebView has no `navigator.xr`; it does not claim a native immersive renderer. Avatar Lab's Source chooser now always shows icon + text and sizes to the labels.

## 0.1.278 / server 9.6.505 / r533

Homepage showcase content is operator-owned. Client ZIP updates preserve an existing `homepage/content.json`, release commits exclude local operator edits, and normal homepage releases publish the exact current local `content.json` and verify the public copy matches it. Use `./scripts/deploy_homepage_content.sh` when only video/gallery content needs publishing. Homepage release notes are generated from the same `DEVELOPMENT_RELEASES` chain used by Rantlist `#development`.

## 0.1.277 / server 9.6.502 / r530

This client is synchronized to Rantlist 9.6.502 / rantlist-deploy-r530. Avatar Lab now uses a separate Blender-compatible Stage preview GLB instead of trying to load the Meshopt-compressed runtime Stage artifact, exposes that editable GLB as a Blender download, hides the optional server add-on choice unless configured, and carries the Stage root-motion/private-avatar alignment repair.

## 0.1.276 / server 9.6.501 / r529

## Client verifier recovery after r529 synchronization

This client is synchronized to Rantlist 9.6.501 / rantlist-deploy-r529 and fixes the r526 regression verifier so it accepts later compatible server/client releases instead of requiring the historical version to remain exactly 9.6.498. The r526 Avatar Lab UI and four-view behavior are unchanged.

## 0.1.275 / server 9.6.498 / r526

## Avatar Lab four-view picker and compact UI repair

This client pairs with Rantlist 9.6.498 / rantlist-deploy-r526. Four-view mode now starts empty and explicit: clicking any My Images card assigns that exact image to the selected Front/Left/Back/Right slot. The selected slot drives the Reference preview. Source/Reference headers are shorter, the redundant Source metadata ribbon is removed, minimized My Models keeps its controls visible, and Prompt & library uses a clear rotating SVG chevron.

## 0.1.274 / server 9.6.497 / r525


## Avatar Lab r525 Tripo startup diagnostics

This client pairs with Rantlist 9.6.497 / rantlist-deploy-r525. High-resolution Avatar Lab image/multiview starts now use a request-scoped heartbeat and show server-received, payload, credential, upload/retry, and task-creation phases before a Tripo task ID exists. Reconnects query the same start request rather than silently leaving the UI busy.

- Avatar Lab r524: uncropped 2D settings, xAI 2K/quality controls and true source dimensions, Tripo four-view generation and explicit key validation, retained optimized versions, optimized-stage auto-selection, and less brittle local Blender body rigging.

## 0.1.272 / server 9.6.495 / r523

Homepage showcase update: uses the real Rantlist app icon, displays the semantic app version separately from the release build tag, adds a JSON-driven HLS video carousel with centered/peeked slides, drag/swipe navigation and clickable dots, and adds a content-only deployment script so future video/gallery edits do not create a native client release.

## 0.1.269 / server 9.6.495 / r523

Desktop DEB metadata hotfix: adds the required project homepage, structured author email metadata, and explicit Linux/DEB maintainer metadata for electron-builder 26.15.3. Adds regression checks for the exact FPM/DEB metadata requirements that blocked 0.1.268 after AppImage creation.

## 0.1.268 / server 9.6.495 / r523

Desktop build hotfix: electron-builder 26.15.3 Linux desktop metadata now uses the required `linux.desktop.entry` schema; package author/desktopName and explicit Linux/Windows executable names are set. Adds regression checks for the exact builder configuration shape that blocked 0.1.267.

## 0.1.267 / server 9.6.495 / r523

- Adds the first Rantlist desktop source for Windows x64 and Linux x86_64.
- Linux builds produce AppImage + DEB; Windows builds produce a portable ZIP + NSIS installer.
- Desktop builds are designed for the dedicated `/srv/rantlist-build` workspace, refuse root execution, run at low priority, and never install packages, restart services, invoke Docker, or touch production data.
- The desktop shell loads only the production Rantlist HTTPS origin with Node integration disabled, context isolation enabled and Chromium sandboxing enabled.


## 0.1.266 / server 9.6.469 / r497

- Avatar Lab compact My Models cards no longer clip their action row.
- Missing generated/imported model thumbnails are backfilled server-side; Tripo preview is preferred and Blender renders the fallback.
- Model optimizer drawer is denser; Actions and Prompt & library are collapsible; prompt editor is shorter by default.
- Main CSP now permits trusted Meshopt WebAssembly compilation.
- Meshy is labeled optional and is only used for external automatic rigging.
## Client 0.1.266 / source 9.6.469
Avatar Lab model-library and optimization-studio synchronization: image-first model cards, imported-model thumbnails, aggressive Mobile optimization controls, before/after metrics, Meshopt + Draco preview decoding.

# Rantlist Client 0.1.264

Synchronized browser/native client for server `9.6.467` / `rantlist-deploy-r495`.

- Carries the r493 Avatar Lab cleanup, model inspector and optimizer.
- Synchronizes the r494 historical-verifier deployment recovery.
- Keeps strict automatic full-finger validation without restoring the removed confusing checkbox.

# Rantlist Client 0.1.262

Synchronized browser/native client for server `9.6.465` / `rantlist-deploy-r493`.

Avatar Lab now uses one GLB/FBX import that is inspected automatically, exposes a separate model inspector/optimizer with before/after metrics and presets, and provides a working xAI API-key shortcut from Reference settings.

Avatar Lab adds the Stage Avatar Builder controls for selecting the installed local Mixamo FBX animation pack, strict articulated-finger validation, geometry target, base-colour-only output and WebP quality. Generated `-stage.glb` assets are preferred in My Models and Add to Stage.
