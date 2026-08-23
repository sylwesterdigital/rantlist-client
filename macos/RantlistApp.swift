import Cocoa
@preconcurrency import WebKit

private let defaultAppURL = "https://rantlist.me/"
private let allowedHosts: Set<String> = ["rantlist.me", "www.rantlist.me"]

private func configuredAppURL() -> URL {
    let value = ProcessInfo.processInfo.environment["RANTLIST_APP_URL"] ?? defaultAppURL
    guard let url = URL(string: value),
          url.scheme?.lowercased() == "https",
          let host = url.host?.lowercased(),
          allowedHosts.contains(host) else {
        fatalError("RANTLIST_APP_URL must be an HTTPS URL on rantlist.me")
    }
    return url
}

private func isRantlistURL(_ url: URL?) -> Bool {
    guard let url,
          url.scheme?.lowercased() == "https",
          let host = url.host?.lowercased() else { return false }
    return allowedHosts.contains(host)
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var downloads: [WKDownload] = []
    private let appURL = configuredAppURL()

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsMagnification = true
        webView.setValue(false, forKey: "drawsBackground")

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1380, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Rantlist"
        window.minSize = NSSize(width: 760, height: 560)
        window.center()
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)

        webView.load(URLRequest(url: appURL, cachePolicy: .useProtocolCachePolicy))
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "Rantlist")
        appMenuItem.submenu = appMenu

        let aboutItem = NSMenuItem(
            title: "About Rantlist",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(aboutItem)

        let websiteItem = NSMenuItem(
            title: "Rantlist Website",
            action: #selector(openWebsite),
            keyEquivalent: ""
        )
        websiteItem.target = self
        appMenu.addItem(websiteItem)

        appMenu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "Hide Rantlist",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        hideItem.target = NSApp
        appMenu.addItem(hideItem)

        let quitItem = NSMenuItem(
            title: "Quit Rantlist",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        appMenu.addItem(quitItem)

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        let reloadItem = NSMenuItem(
            title: "Reload",
            action: #selector(reloadPage),
            keyEquivalent: "r"
        )
        reloadItem.target = self
        viewMenu.addItem(reloadItem)

        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu
        let helpItem = NSMenuItem(
            title: "Rantlist Help",
            action: #selector(openHelp),
            keyEquivalent: "?"
        )
        helpItem.target = self
        helpMenu.addItem(helpItem)

        NSApp.mainMenu = mainMenu
        NSApp.helpMenu = helpMenu
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openWebsite() {
        NSWorkspace.shared.open(appURL)
    }

    @objc private func openHelp() {
        NSWorkspace.shared.open(appURL)
    }

    @objc private func reloadPage() {
        webView?.reload()
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        if #available(macOS 11.3, *), navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""
        if isRantlistURL(url) || ["about", "blob", "data"].contains(scheme) {
            decisionHandler(.allow)
            return
        }

        // Embedded HTTPS content stays in WKWebView. External pages open only
        // after an explicit user click, so widgets cannot launch a browser on load.
        if let targetFrame = navigationAction.targetFrame,
           !targetFrame.isMainFrame,
           scheme == "https" {
            decisionHandler(.allow)
            return
        }

        if ["https", "mailto", "tel"].contains(scheme),
           navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if #available(macOS 11.3, *), !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil,
              let url = navigationAction.request.url else { return nil }
        if isRantlistURL(url) {
            webView.load(URLRequest(url: url))
        } else if ["https", "mailto", "tel"].contains(url.scheme?.lowercased() ?? ""),
                  navigationAction.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.resolvesAliases = true

        if let window = webView.window {
            panel.beginSheetModal(for: window) { response in
                completionHandler(response == .OK ? panel.urls : nil)
            }
        } else {
            completionHandler(panel.runModal() == .OK ? panel.urls : nil)
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        if let window = webView.window {
            alert.beginSheetModal(for: window) { _ in completionHandler() }
        } else {
            alert.runModal()
            completionHandler()
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        if let window = webView.window {
            alert.beginSheetModal(for: window) { response in
                completionHandler(response == .alertFirstButtonReturn)
            }
        } else {
            completionHandler(alert.runModal() == .alertFirstButtonReturn)
        }
    }

    @available(macOS 12.0, *)
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let trusted = origin.protocol.lowercased() == "https" && allowedHosts.contains(origin.host.lowercased())
        decisionHandler(trusted ? .grant : .deny)
    }

    @available(macOS 11.3, *)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        downloads.append(download)
        download.delegate = self
    }

    @available(macOS 11.3, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        downloads.append(download)
        download.delegate = self
    }

    @available(macOS 11.3, *)
    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { result in
            completionHandler(result == .OK ? panel.url : nil)
        }
    }

    @available(macOS 11.3, *)
    func downloadDidFinish(_ download: WKDownload) {
        downloads.removeAll { $0 === download }
    }

    @available(macOS 11.3, *)
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloads.removeAll { $0 === download }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Download failed"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}

if CommandLine.arguments.contains("--smoke-test") {
    let url = configuredAppURL()
    guard url.scheme == "https", isRantlistURL(url) else { exit(2) }
    print("Rantlist macOS client smoke test passed: \(url.absoluteString)")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
