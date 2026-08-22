import SwiftUI
@preconcurrency import WebKit

private let appURL = URL(string: "https://rantlist.me/")!
private let allowedHosts: Set<String> = ["rantlist.me", "www.rantlist.me"]

private func trusted(_ url: URL?) -> Bool {
    guard let url,
          url.scheme?.lowercased() == "https",
          let host = url.host?.lowercased() else { return false }
    return allowedHosts.contains(host)
}

@main
struct RantlistMobileApp: App {
    var body: some Scene {
        WindowGroup {
            RantlistWebView()
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

struct RantlistWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.load(URLRequest(url: appURL, cachePolicy: .useProtocolCachePolicy))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if trusted(url) || ["about", "blob", "data"].contains(url.scheme?.lowercased() ?? "") {
                decisionHandler(.allow)
                return
            }
            if ["https", "mailto", "tel"].contains(url.scheme?.lowercased() ?? "") {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard navigationAction.targetFrame == nil,
                  let url = navigationAction.request.url else { return nil }
            if trusted(url) {
                webView.load(URLRequest(url: url))
            } else if ["https", "mailto", "tel"].contains(url.scheme?.lowercased() ?? "") {
                UIApplication.shared.open(url)
            }
            return nil
        }

        @available(iOS 15.0, *)
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            let trustedOrigin = origin.protocol.lowercased() == "https" && allowedHosts.contains(origin.host.lowercased())
            decisionHandler(trustedOrigin ? .grant : .deny)
        }
    }
}
