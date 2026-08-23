import AVFoundation
import Network
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

private enum NativeShellPhase: Equatable {
    case loading
    case offline
    case failed
    case ready
}

private final class NativeShellState: ObservableObject {
    @Published var phase: NativeShellPhase = .loading
    @Published var detail = "Connecting to rantlist.me…"
    var hasLoadedUI = false
    var retryAction: (() -> Void)?

    func retry() { retryAction?() }
}

@main
struct RantlistMobileApp: App {
    var body: some Scene {
        WindowGroup {
            RantlistRootView()
                .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

private struct RantlistRootView: View {
    @StateObject private var shellState = NativeShellState()

    var body: some View {
        ZStack {
            RantlistWebView(shellState: shellState)
                .opacity(shellState.hasLoadedUI ? 1 : 0)

            if shellState.phase != .ready {
                NativeShellOverlay(shellState: shellState)
                    .transition(.opacity)
            }
        }
        .background(Color(red: 0.025, green: 0.035, blue: 0.05))
    }
}

private struct NativeShellOverlay: View {
    @ObservedObject var shellState: NativeShellState

    private var title: String {
        switch shellState.phase {
        case .loading: return "Rantlist"
        case .offline: return "No internet connection"
        case .failed: return "Rantlist couldn’t load"
        case .ready: return "Rantlist"
        }
    }

    private var message: String {
        switch shellState.phase {
        case .loading:
            return shellState.detail
        case .offline:
            return "Connect to Wi‑Fi or cellular data. Rantlist will retry automatically when you’re online."
        case .failed:
            return shellState.detail
        case .ready:
            return ""
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Color.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if shellState.phase == .loading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .padding(.top, 2)
            } else if shellState.phase == .offline || shellState.phase == .failed {
                Button("Try again") { shellState.retry() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.025, green: 0.035, blue: 0.05).ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }
}

private struct RantlistWebView: UIViewRepresentable {
    @ObservedObject var shellState: NativeShellState

    func makeCoordinator() -> Coordinator { Coordinator(shellState: shellState) }

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
        context.coordinator.attach(to: webView)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 13.0, *) {
            webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        }
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.isDirectionalLockEnabled = true
        context.coordinator.beginInitialLoad()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, UIDocumentPickerDelegate {
        private weak var webView: WKWebView?
        private let shellState: NativeShellState
        private let pathMonitor = NWPathMonitor()
        private let pathQueue = DispatchQueue(label: "fun.workwork.rantlist.network")
        private var monitoringStarted = false
        private var downloads: [WKDownload] = []
        private var downloadDestinations: [ObjectIdentifier: URL] = [:]
        private var exportTemporaryDirectories: [ObjectIdentifier: URL] = [:]

        init(shellState: NativeShellState) {
            self.shellState = shellState
            super.init()
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardDidHide), name: UIResponder.keyboardDidHideNotification, object: nil)
            center.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        }

        deinit {
            pathMonitor.cancel()
            NotificationCenter.default.removeObserver(self)
        }

        func attach(to webView: WKWebView) {
            self.webView = webView
            shellState.retryAction = { [weak self] in self?.retryInitialLoad() }
            startNetworkMonitoring()
        }

        func beginInitialLoad() {
            guard let webView else { return }
            shellState.phase = .loading
            shellState.detail = "Connecting to rantlist.me…"
            webView.load(URLRequest(url: appURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30))
        }

        private func startNetworkMonitoring() {
            guard !monitoringStarted else { return }
            monitoringStarted = true
            pathMonitor.pathUpdateHandler = { [weak self] path in
                DispatchQueue.main.async {
                    self?.handleNetworkPath(path)
                }
            }
            pathMonitor.start(queue: pathQueue)
        }

        private func handleNetworkPath(_ path: NWPath) {
            if path.status == .satisfied {
                if shellState.hasLoadedUI {
                    shellState.phase = .ready
                } else {
                    retryInitialLoad()
                }
            } else {
                shellState.phase = .offline
                shellState.detail = "No network connection is available."
            }
        }

        private func retryInitialLoad() {
            guard let webView else { return }
            guard pathMonitor.currentPath.status == .satisfied else {
                shellState.phase = .offline
                shellState.detail = "No network connection is available."
                return
            }
            if shellState.hasLoadedUI {
                shellState.phase = .ready
                return
            }
            shellState.phase = .loading
            shellState.detail = "Connecting to rantlist.me…"
            webView.stopLoading()
            webView.load(URLRequest(url: appURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
        }

        @objc private func applicationDidBecomeActive() {
            guard !shellState.hasLoadedUI else { return }
            DispatchQueue.main.async { [weak self] in self?.retryInitialLoad() }
        }

        private func isConnectivityError(_ error: Error) -> Bool {
            let nsError = error as NSError
            guard nsError.domain == NSURLErrorDomain else { return false }
            return [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorTimedOut,
            ].contains(nsError.code)
        }

        private func handleLoadFailure(_ error: Error) {
            guard !shellState.hasLoadedUI else {
                if pathMonitor.currentPath.status != .satisfied { shellState.phase = .offline }
                return
            }
            if isConnectivityError(error) || pathMonitor.currentPath.status != .satisfied {
                shellState.phase = .offline
                shellState.detail = "No network connection is available."
            } else {
                shellState.phase = .failed
                shellState.detail = "The Rantlist interface could not be downloaded. Check your connection and try again."
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            if !shellState.hasLoadedUI {
                shellState.phase = .loading
                shellState.detail = "Loading Rantlist…"
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard trusted(webView.url) else { return }
            shellState.hasLoadedUI = true
            shellState.phase = .ready
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleLoadFailure(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleLoadFailure(error)
        }

        private func sendKeyboardPhase(_ phase: String) {
            DispatchQueue.main.async { [weak self] in
                self?.webView?.evaluateJavaScript(
                    "window.rantlistNativeKeyboardPhase && window.rantlistNativeKeyboardPhase('\\(phase)');",
                    completionHandler: nil
                )
            }
        }

        @objc private func keyboardWillShow(_ notification: Notification) { sendKeyboardPhase("willShow") }
        @objc private func keyboardDidShow(_ notification: Notification) { sendKeyboardPhase("didShow") }
        @objc private func keyboardWillHide(_ notification: Notification) { sendKeyboardPhase("willHide") }
        @objc private func keyboardDidHide(_ notification: Notification) { sendKeyboardPhase("didHide") }

        private func isDownloadURL(_ url: URL) -> Bool {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
            return components.queryItems?.contains { item in
                item.name.lowercased() == "download" && ["1", "true", "yes"].contains((item.value ?? "").lowercased())
            } ?? false
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if navigationAction.shouldPerformDownload || isDownloadURL(url) {
                decisionHandler(.download)
                return
            }
            let scheme = url.scheme?.lowercased() ?? ""
            if trusted(url) || ["about", "blob", "data"].contains(scheme) {
                decisionHandler(.allow)
                return
            }

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
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            let disposition = (navigationResponse.response as? HTTPURLResponse)?
                .value(forHTTPHeaderField: "Content-Disposition")?
                .lowercased() ?? ""
            if disposition.contains("attachment") || !navigationResponse.canShowMIMEType {
                decisionHandler(.download)
            } else {
                decisionHandler(.allow)
            }
        }

        private func downloadDestination(for suggestedFilename: String) throws -> URL {
            let fileManager = FileManager.default
            let directory = fileManager.temporaryDirectory
                .appendingPathComponent("RantlistDownloads", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let filename = URL(fileURLWithPath: suggestedFilename).lastPathComponent
            let safeFilename = filename.isEmpty ? "Rantlist-download" : filename
            return directory.appendingPathComponent(safeFilename, isDirectory: false)
        }

        private func presentDownloadExporter(for fileURL: URL) {
            guard let webView,
                  let presenter = topViewController(from: webView.window?.rootViewController) else { return }
            let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
            picker.shouldShowFileExtensions = true
            picker.delegate = self
            exportTemporaryDirectories[ObjectIdentifier(picker)] = fileURL.deletingLastPathComponent()
            presenter.present(picker, animated: true)
        }

        private func cleanUpExport(for picker: UIDocumentPickerViewController) {
            guard let directory = exportTemporaryDirectories.removeValue(forKey: ObjectIdentifier(picker)) else { return }
            try? FileManager.default.removeItem(at: directory)
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            cleanUpExport(for: controller)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            cleanUpExport(for: controller)
        }

        private func showDownloadFailure(_ error: Error) {
            guard let webView,
                  let presenter = topViewController(from: webView.window?.rootViewController) else { return }
            let alert = UIAlertController(title: "Download failed", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presenter.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView,
                     navigationAction: WKNavigationAction,
                     didBecome download: WKDownload) {
            downloads.append(download)
            download.delegate = self
        }

        func webView(_ webView: WKWebView,
                     navigationResponse: WKNavigationResponse,
                     didBecome download: WKDownload) {
            downloads.append(download)
            download.delegate = self
        }

        func download(_ download: WKDownload,
                      decideDestinationUsing response: URLResponse,
                      suggestedFilename: String,
                      completionHandler: @escaping (URL?) -> Void) {
            do {
                let destination = try downloadDestination(for: suggestedFilename)
                downloadDestinations[ObjectIdentifier(download)] = destination
                completionHandler(destination)
            } catch {
                completionHandler(nil)
                DispatchQueue.main.async { [weak self] in self?.showDownloadFailure(error) }
            }
        }

        func downloadDidFinish(_ download: WKDownload) {
            downloads.removeAll { $0 === download }
            guard let destination = downloadDestinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
            DispatchQueue.main.async { [weak self] in self?.presentDownloadExporter(for: destination) }
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            downloads.removeAll { $0 === download }
            if let destination = downloadDestinations.removeValue(forKey: ObjectIdentifier(download)) {
                try? FileManager.default.removeItem(at: destination.deletingLastPathComponent())
            }
            DispatchQueue.main.async { [weak self] in self?.showDownloadFailure(error) }
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

        private func topViewController(from root: UIViewController?) -> UIViewController? {
            if let presented = root?.presentedViewController {
                return topViewController(from: presented)
            }
            if let navigation = root as? UINavigationController {
                return topViewController(from: navigation.visibleViewController)
            }
            if let tabs = root as? UITabBarController {
                return topViewController(from: tabs.selectedViewController)
            }
            return root
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            guard let presenter = topViewController(from: webView.window?.rootViewController) else {
                completionHandler()
                return
            }
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            presenter.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            guard let presenter = topViewController(from: webView.window?.rootViewController) else {
                completionHandler(false)
                return
            }
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
            presenter.present(alert, animated: true)
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
