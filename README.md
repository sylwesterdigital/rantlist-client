# Rantlist client 0.1.237

Synchronized source: **9.6.421 / rantlist-deploy-r449**
Released: **2026-09-29**

This client fixes native mobile interaction around reactions, PDF documents and Android sharing. Mobile reaction picking remains open while adding multiple emoji and preserves the message timeline position. iOS opens Rantlist PDFs in a dismissible native document view with an explicit Done action. Android routes authenticated Rantlist PDF previews through DownloadManager and the system PDF viewer without storage permission, and registers Rantlist as an Android share target for text, links, single files and multiple files using an origin-scoped WebMessagePort bridge.

The synchronized browser core also retains the r448 YouTube recovery and safe TXT preview/open behavior. Protocol 70 and Stage schema 1266 are unchanged.
