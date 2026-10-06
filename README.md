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
