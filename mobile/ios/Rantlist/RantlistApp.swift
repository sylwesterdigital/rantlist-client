import AVFoundation
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

private func requestCaptureAuthorization(_ mediaType: AVMediaType,
                                         completion: @escaping (Bool) -> Void) {
    switch AVCaptureDevice.authorizationStatus(for: mediaType) {
    case .authorized:
        completion(true)
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: mediaType) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    case .denied, .restricted:
        completion(false)
    @unknown default:
        completion(false)
    }
}

private func requestCaptureAuthorization(_ type: WKMediaCaptureType,
                                         completion: @escaping (Bool) -> Void) {
    switch type {
    case .camera:
        requestCaptureAuthorization(.video, completion: completion)
    case .microphone:
        requestCaptureAuthorization(.audio, completion: completion)
    case .cameraAndMicrophone:
        requestCaptureAuthorization(.video) { cameraGranted in
            guard cameraGranted else {
                completion(false)
                return
            }
            requestCaptureAuthorization(.audio, completion: completion)
        }
    @unknown default:
        completion(false)
    }
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
        config.applicationNameForUserAgent = "Rantlist-iOS"

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 13.0, *) {
            webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        }
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
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
            let scheme = url.scheme?.lowercased() ?? ""
            if trusted(url) || ["about", "blob", "data"].contains(scheme) {
                decisionHandler(.allow)
                return
            }

            // Keep embedded HTTPS content (for example Stripe Buy Button frames)
            // inside the app. Only explicit user-activated external links are
            // handed to the system browser.
            if let targetFrame = navigationAction.targetFrame,
               !targetFrame.isMainFrame,
               scheme == "https" {
                decisionHandler(.allow)
                return
            }

            if ["https", "mailto", "tel"].contains(scheme),
               navigationAction.navigationType == .linkActivated {
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
            } else if ["https", "mailto", "tel"].contains(url.scheme?.lowercased() ?? ""),
                      navigationAction.navigationType == .linkActivated {
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
            let trustedOrigin = origin.protocol.lowercased() == "https"
                && allowedHosts.contains(origin.host.lowercased())
            guard trustedOrigin else {
                decisionHandler(.deny)
                return
            }

            requestCaptureAuthorization(type) { granted in
                decisionHandler(granted ? .grant : .deny)
            }
        }
    }
}
