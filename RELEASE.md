# Rantlist client 0.1.232

Synchronized source: **9.6.400 / rantlist-deploy-r428**
Released: **2026-09-29T07:52:51+01:00**

Packaging-only corrective client release. It keeps the r428 browser/native source unchanged and removes trailing Markdown whitespace from the synchronized release metadata that caused `release_and_deploy_homepage.sh` preflight to stop before the macOS/iOS build. No Stage protocol, Engineer synchronization, UI, or native runtime behavior changes are introduced by 0.1.232.

## Client 0.1.230 / server 9.6.399 — r427 authoritative Stage replay

This full client matches server 9.6.399/r427. The browser bridge now force-applies authoritative `stage.world.state` resyncs so an iframe that missed live edits while a larger world was hydrating cannot remain on an older local scene. The Stage runtime coalesces repeated self-contained Engineer assembly updates for the same chassis and requests a server resync instead of silently dropping collaboration events if its bounded replay queue is exceeded.

Protocol 70 and Stage schema 1266 are unchanged.

Deploy server 9.6.399/r427 first, then this client package.
