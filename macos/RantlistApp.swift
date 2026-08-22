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
