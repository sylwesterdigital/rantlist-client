# Rantlist client 0.1.240

Bundled browser baseline: **9.6.421 / rantlist-deploy-r449**
Released: **2026-10-01**

- Detect Quest/Horizon-class Android hardware using Android VR system features plus Quest/Oculus/Meta manufacturer/model signals.
- Append `Rantlist-XR-Headset` alongside `Rantlist-Android` only on those devices.
- Keep actual immersive capability fail-closed and runtime-driven; the UA marker never fabricates `navigator.xr`.
- Add a client regression check for the headset marker and Android APK/AAB build path.
- Keep the standalone bundled web snapshot at the r449 baseline; automatic native release still synchronizes current verified server web content before build.

# Rantlist client 0.1.239

Bundled browser baseline: **9.6.421 / rantlist-deploy-r449**
Released: **2026-09-30**

- Remove trailing Markdown whitespace from `README.md` and `RELEASE.md` that caused the native release preflight `git diff --check` to reject the otherwise valid 0.1.238 package after Stage synchronization.
- Add `scripts/verify_source_whitespace.js` to `verify_client_repo.sh`, so the same non-web trailing-whitespace class is rejected during the watcher verification step, before signing/build/release begins.
- Fix `scripts/verify_mobile_native_r449.js` so the historical r449 regression accepts synchronized **r449-or-later** server/browser releases instead of hard-coding exactly `9.6.421 / rantlist-deploy-r449`.
- Keep the r449 native/mobile assertions themselves unchanged: reaction-picker stability, iOS native PDF return, Android authenticated PDF handoff, and Android share target/WebMessagePort behavior are still verified.
- Keep `PACKAGE_VERSION.txt` as the independent watcher package version (`0.1.239`).
- Keep `VERSION.txt` as the synchronized application version authority; `scripts/sync_from_stage.sh` continues replacing it together with `web/` from the current `stage/chat` source before native release verification/build.
- This prevents a valid server update such as `9.6.436 / rantlist-deploy-r464` from failing solely because a historical client verifier expected the original r449 release number.
- Protocol 70 and Stage schema 1266 are unchanged.
