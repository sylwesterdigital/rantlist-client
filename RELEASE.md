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

- Quest Bubblewrap immersive bridge remains the r538 implementation.
- Release metadata is synchronized with server 9.6.511 / rantlist-deploy-r539.
- Manual updater use can now rely on server watcher `--once`; no Ctrl-C is required after successful processing.

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

Adds Windows/Linux Electron desktop source and isolated Ubuntu build scripts. Linux targets AppImage + DEB; Windows targets x64 portable ZIP + NSIS installer. Build scripts are restricted to the dedicated build workspace and contain no package-manager/service/Docker operations.


## 0.1.266 / server 9.6.469 / r497

- Avatar Lab compact My Models cards no longer clip their action row.
- Missing generated/imported model thumbnails are backfilled server-side; Tripo preview is preferred and Blender renders the fallback.
- Model optimizer drawer is denser; Actions and Prompt & library are collapsible; prompt editor is shorter by default.
- Main CSP now permits trusted Meshopt WebAssembly compilation.
- Meshy is labeled optional and is only used for external automatic rigging.
# Rantlist Client 0.1.266

Source: `9.6.469` / `rantlist-deploy-r497`

Avatar Lab model cards now keep previews unobstructed; imported models get persistent Blender thumbnails; Model Optimization exposes High/Balanced/Mobile profiles, actual mesh/texture/skin/animation pipeline stages and before/after metrics. Avatar Lab preview supports Meshopt and Draco optimized GLBs.

# Rantlist Client 0.1.264

Source: `9.6.467` / `rantlist-deploy-r495`

- Synchronizes the Avatar Lab historical-verifier deployment recovery.
- r493 model inspector/optimizer UI and automatic rigging behavior remain unchanged.

# Rantlist Client 0.1.262

Source: `9.6.465` / `rantlist-deploy-r493`

- Unified GLB/FBX import with server-side Blender classification.
- Separate model inspector and optimization controls with before/after metrics.
- Working xAI API-key shortcut from Avatar Lab Reference settings.
- Carries the Meshy automatic rigging flow from r491 while removing the confusing dual import/finger-toggle presentation.

# Rantlist Client 0.1.260

Source: `9.6.463` / `rantlist-deploy-r491`

Avatar Lab automatic rigging now uses Meshy BYOK for programmatic humanoid rigging of generated or imported unrigged GLBs, validates the complete finger chain before local Mixamo action merge, and keeps already-rigged imports on the no-regeneration/no-rerig path. Build-status polling is self-healing and native credential bridges include Meshy.

# Rantlist Client 0.1.259

Source: `9.6.462` / `rantlist-deploy-r490`

- Compact Source → 2D reference action.
- Normal-sized aligned Stage Avatar Builder checkboxes.
- Visible Import unrigged GLB/FBX and Import Mixamo-rigged GLB/FBX controls.
- Live Blender launch/heartbeat/stage diagnostics in Avatar Lab logs.

## 0.1.281 Android / Quest split

- `mobile/android` remains the normal native WebView Android phone/tablet client.
- `mobile/quest` is a separate Meta Quest 2D Trusted Web Activity package using Meta Android Browser Helper.
- `scripts/build_android_release.sh` builds the phone APK/AAB.
- `scripts/build_quest_release.sh` builds the separate Quest APK/AAB.
- Both use the existing Rantlist Android signing identity; Quest keeps package `fun.workwork.rantlist` so the r536 `rantlist.me` Digital Asset Links relationship remains valid.
