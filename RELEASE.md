# Rantlist client 0.1.237

Synchronized source: **9.6.421 / rantlist-deploy-r449**
Released: **2026-09-29**

- Keep the mobile reaction picker open for successive emoji reactions and preserve the message scroll anchor while reaction chips change height.
- Open PDFs on iOS in a separate native document view with an explicit Done action so chat is never replaced.
- Open authenticated Rantlist PDFs on Android through DownloadManager and a system PDF viewer, without broad storage permission.
- Register Android `ACTION_SEND` and `ACTION_SEND_MULTIPLE` so Rantlist appears in the system share sheet for text, URLs and files.
- Transfer Android shared files to the existing Rantlist pending-share flow through an origin-scoped WebMessagePort channel.
- Synchronize browser source 9.6.421 / rantlist-deploy-r449, including r448 TXT and YouTube fixes.
- Protocol 70 and Stage schema 1266 are unchanged.
