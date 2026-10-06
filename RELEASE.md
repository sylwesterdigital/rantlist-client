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
