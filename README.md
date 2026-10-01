# Rantlist client 0.1.241

Bundled browser baseline: **9.6.441 / rantlist-deploy-r469**
Released: **2026-10-01**

This client release synchronizes the browser shell with server r469 so a fresh channel cannot inherit a personal/default Stage World or retained geometry from another channel. The native wrappers themselves are unchanged; Android still includes the Quest/Horizon `Rantlist-XR-Headset` marker and APK/AAB release path from 0.1.240.

A paired client regression now checks the r469 `empty-world` handoff whenever the synchronized source is r469 or later. Automatic release still re-synchronizes `web/`, `VERSION.txt`, and `web/client-source.json` from the currently deployed verified Stage/chat source immediately before native builds.

# Rantlist client 0.1.240

Bundled browser baseline: **9.6.421 / rantlist-deploy-r449**
Released: **2026-10-01**

This native-client release marks Quest/Horizon-class Android hardware with the bounded `Rantlist-XR-Headset` user-agent token in addition to the existing `Rantlist-Android` marker. Detection uses Android VR system features plus Quest/Oculus/Meta manufacturer/model signals. The marker only helps the Stage rendering/device classifier; WebXR availability itself remains determined by the browser runtime's `navigator.xr.isSessionSupported('immersive-vr')`.

The package also verifies that the Android release path remains present. Server release `9.6.440 / rantlist-deploy-r468` restores the active Downloads watcher default to `macos,android,ios`, so future automatic client releases again build/publish APK + AAB along with macOS and iOS.

This maintenance package fixes the native-client verification contract used by the automatic release workflow. The client repository deliberately synchronizes `web/`, `VERSION.txt`, and `web/client-source.json` from the currently deployed `stage/chat` server immediately before verification/build. Historical r449 verification therefore validates **r449-or-later compatibility** instead of requiring the synchronized source to remain exactly 9.6.421 / r449.

The native behavior introduced by r449 is unchanged: mobile reaction picking remains open while adding multiple emoji and preserves the message timeline position; iOS opens Rantlist PDFs in a dismissible native document view; Android routes authenticated Rantlist PDF previews through DownloadManager/system viewers and accepts Android share-sheet input through the origin-scoped WebMessagePort bridge.


This maintenance release also fixes the native release preflight itself: the prior 0.1.238 package contained Markdown hard-break trailing spaces in `README.md` and `RELEASE.md`, which `git diff --check` correctly rejected after the browser snapshot was synchronized from Stage. Those trailing spaces are removed, and standalone client verification now runs an equivalent non-web source whitespace check before the release workflow starts.

The bundled snapshot remains the r449 baseline only so the standalone package is self-verifying before synchronization. During automatic release, `scripts/sync_from_stage.sh` replaces that browser snapshot with the current verified Rantlist server UI/revision. Protocol 70 and Stage schema 1266 remain unchanged.
