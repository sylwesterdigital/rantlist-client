import AVFoundation
import Network
import Security
import SwiftUI
import UserNotifications
@preconcurrency import WebKit

private let appURL = URL(string: "https://rantlist.me/")!
private let allowedHosts: Set<String> = ["rantlist.me", "www.rantlist.me"]


private enum SecureOpenAiCredentialStore {
    private static let service = "fun.workwork.rantlist.openai"
    private static let account = "user-api-key"

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        clear()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private let appGroupIdentifier = "group.fun.workwork.rantlist"
private let nativeShareScheme = "rantlist-share"

private extension Notification.Name {
    static let rantlistPushTokenDidUpdate = Notification.Name("RantlistPushTokenDidUpdate")
    static let rantlistPushBadgeNeedsSync = Notification.Name("RantlistPushBadgeNeedsSync")
    static let rantlistSharedInboxDidUpdate = Notification.Name("RantlistSharedInboxDidUpdate")
    static let rantlistOpenRoom = Notification.Name("RantlistOpenRoom")
}

private final class NativeBridgeState {
    static let shared = NativeBridgeState()
    var pushToken: String?
    #if DEBUG
    let pushEnvironment = "sandbox"
    #else
    let pushEnvironment = "production"
    #endif
    var pendingRoom: String?
}

private enum NativeShareSessionStore {
    private static func sessionURL(createParent: Bool = false) -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return nil }
        let directory = container.appendingPathComponent("Library/Application Support/RantlistShareSession", isDirectory: true)
        if createParent { try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        return directory.appendingPathComponent("session-v1.json", isDirectory: false)
    }

    static func save(_ body: [String: Any]) {
        guard let identityId = body["identityId"] as? String,
              identityId.range(of: "^[A-Za-z0-9_-]{16,80}$", options: .regularExpression) != nil,
              let nickname = body["nickname"] as? String,
              !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var payload = body
        payload.removeValue(forKey: "action")
        payload["savedAt"] = Date().timeIntervalSince1970
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let url = sessionURL(createParent: true) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func clear() {
        guard let url = sessionURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

private struct NativeShareManifest: Codable {
    struct Item: Codable {
        let id: String
        let kind: String
        let name: String
        let mime: String
        let relativePath: String?
        let text: String?
        let url: String?
    }
    let id: String
    let createdAt: Double
    let items: [Item]
}

private enum NativeShareInbox {
    static func rootURL(create: Bool = false) -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return nil }
        let root = container.appendingPathComponent("Library/Application Support/RantlistShareInbox", isDirectory: true)
        if create { try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
        return root
    }

    static func manifestURL(shareID: String) -> URL? {
        guard shareID.range(of: "^[A-Fa-f0-9-]{8,64}$", options: .regularExpression) != nil,
              let root = rootURL() else { return nil }
        return root.appendingPathComponent(shareID, isDirectory: true).appendingPathComponent("manifest.json")
    }

    static func loadManifest(shareID: String) -> NativeShareManifest? {
        guard let url = manifestURL(shareID: shareID),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(NativeShareManifest.self, from: data)
    }

    static func pendingPayload() -> [[String: Any]] {
        guard let root = rootURL(create: true),
              let dirs = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        return dirs.compactMap { dir in
            guard let data = try? Data(contentsOf: dir.appendingPathComponent("manifest.json")),
                  let manifest = try? JSONDecoder().decode(NativeShareManifest.self, from: data) else { return nil }
            let items: [[String: Any]] = manifest.items.compactMap { item in
                var payload: [String: Any] = [
                    "id": item.id,
                    "kind": item.kind,
                    "name": item.name,
                    "mime": item.mime,
                ]
                if item.relativePath != nil {
                    guard fileURL(shareID: manifest.id, itemID: item.id) != nil else { return nil }
                    payload["nativeURL"] = "\(nativeShareScheme)://item/\(manifest.id)/\(item.id)"
                    payload["nativeRead"] = true
                }
                if let text = item.text { payload["text"] = text }
                if let url = item.url { payload["url"] = url }
                return payload
            }
            guard !items.isEmpty else { return nil }
            return ["id": manifest.id, "createdAt": manifest.createdAt, "items": items]
        }.sorted { (lhs, rhs) in
            (lhs["createdAt"] as? Double ?? 0) < (rhs["createdAt"] as? Double ?? 0)
        }
    }

    static func consume(ids: [String]) {
        guard let root = rootURL() else { return }
        for id in ids where id.range(of: "^[A-Fa-f0-9-]{8,64}$", options: .regularExpression) != nil {
            try? FileManager.default.removeItem(at: root.appendingPathComponent(id, isDirectory: true))
        }
    }

    static func fileURL(shareID: String, itemID: String) -> (URL, String)? {
        guard itemID.range(of: "^[A-Fa-f0-9-]{8,64}$", options: .regularExpression) != nil,
              let manifest = loadManifest(shareID: shareID),
              let item = manifest.items.first(where: { $0.id == itemID }),
              let relativePath = item.relativePath,
              !relativePath.contains(".."),
              let root = rootURL() else { return nil }
        let base = root.appendingPathComponent(shareID, isDirectory: true).standardizedFileURL
        let file = base.appendingPathComponent(relativePath, isDirectory: false).standardizedFileURL
        guard file.path.hasPrefix(base.path + "/"),
              FileManager.default.fileExists(atPath: file.path) else { return nil }
        return (file, item.mime.isEmpty ? "application/octet-stream" : item.mime)
    }

    static func itemName(shareID: String, itemID: String) -> String? {
        guard let manifest = loadManifest(shareID: shareID),
              let item = manifest.items.first(where: { $0.id == itemID }) else { return nil }
        return item.name
    }
}

private final class RantlistShareSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              url.scheme == nativeShareScheme,
              url.host == "item" else {
            urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL))
            return
        }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2,
              let (fileURL, mime) = NativeShareInbox.fileURL(shareID: parts[0], itemID: parts[1]),
              let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mime,
                "Content-Length": String(data.count),
                "Cache-Control": "no-store",
                "Access-Control-Allow-Origin": "https://rantlist.me",
            ]
        )!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

final class RantlistAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NativeBridgeState.shared.pushToken = token
        NotificationCenter.default.post(name: .rantlistPushTokenDidUpdate, object: nil)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NativeBridgeState.shared.pushToken = nil
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard url.scheme?.lowercased() == "rantlist" else { return false }
        NotificationCenter.default.post(name: .rantlistSharedInboxDidUpdate, object: nil)
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let isRantlistPush = notification.request.content.userInfo["rantlist"] != nil
        if isRantlistPush {
            // While the app is foregrounded, the WKWebView immediately asks the
            // server for the authoritative unread total. Never let a delayed APNs
            // payload overwrite that newer state with an older badge value.
            NotificationCenter.default.post(name: .rantlistPushBadgeNeedsSync, object: nil)
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.banner, .sound, .badge])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let rantlist = info["rantlist"] as? [String: Any],
           let room = (rantlist["roomKey"] as? String) ?? (rantlist["room"] as? String),
           !room.isEmpty {
            NativeBridgeState.shared.pendingRoom = room
            NotificationCenter.default.post(name: .rantlistOpenRoom, object: nil)
        }
        completionHandler()
    }
}

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
    @UIApplicationDelegateAdaptor(RantlistAppDelegate.self) private var appDelegate

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
        config.userContentController.add(context.coordinator, name: "rantlistBadge")
        config.userContentController.add(context.coordinator, name: "rantlistShare")
        config.userContentController.add(context.coordinator, name: "rantlistSecrets")
        config.setURLSchemeHandler(context.coordinator.shareSchemeHandler, forURLScheme: nativeShareScheme)

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

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "rantlistBadge")
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "rantlistShare")
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "rantlistSecrets")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, UIDocumentPickerDelegate, WKScriptMessageHandler {
        private weak var webView: WKWebView?
        private let shellState: NativeShellState
        private let pathMonitor = NWPathMonitor()
        private let pathQueue = DispatchQueue(label: "fun.workwork.rantlist.network")
        private var monitoringStarted = false
        private var downloads: [WKDownload] = []
        private var downloadDestinations: [ObjectIdentifier: URL] = [:]
        private var exportTemporaryDirectories: [ObjectIdentifier: URL] = [:]
        let shareSchemeHandler = RantlistShareSchemeHandler()

        init(shellState: NativeShellState) {
            self.shellState = shellState
            super.init()
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
            center.addObserver(self, selector: #selector(keyboardDidHide), name: UIResponder.keyboardDidHideNotification, object: nil)
            center.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
            center.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
            center.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
            center.addObserver(self, selector: #selector(pushTokenDidUpdate), name: .rantlistPushTokenDidUpdate, object: nil)
            center.addObserver(self, selector: #selector(pushBadgeNeedsSync), name: .rantlistPushBadgeNeedsSync, object: nil)
            center.addObserver(self, selector: #selector(sharedInboxDidUpdate), name: .rantlistSharedInboxDidUpdate, object: nil)
            center.addObserver(self, selector: #selector(openPendingRoom), name: .rantlistOpenRoom, object: nil)
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

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "rantlistSecrets" {
                handleSecretMessage(message)
                return
            }
            if message.name == "rantlistShare" {
                guard let body = message.body as? [String: Any],
                      let action = body["action"] as? String else { return }
                if action == "session" {
                    NativeShareSessionStore.save(body)
                    return
                }
                if action == "clearSession" {
                    NativeShareSessionStore.clear()
                    return
                }
                if action == "consume", let ids = body["ids"] as? [String] {
                    NativeShareInbox.consume(ids: ids)
                    return
                }
                if action == "read",
                   let requestID = body["requestId"] as? String,
                   let shareID = body["shareId"] as? String,
                   let itemID = body["itemId"] as? String {
                    deliverSharedFile(requestID: requestID, shareID: shareID, itemID: itemID)
                }
                return
            }
            guard message.name == "rantlistBadge" else { return }
            let count: Int
            if let body = message.body as? [String: Any] {
                count = max(0, min(9999, (body["count"] as? NSNumber)?.intValue ?? 0))
            } else if let number = message.body as? NSNumber {
                count = max(0, min(9999, number.intValue))
            } else {
                return
            }
            DispatchQueue.main.async {
                if #available(iOS 16.0, *) {
                    UNUserNotificationCenter.current().setBadgeCount(count) { error in
                        if error != nil {
                            DispatchQueue.main.async { UIApplication.shared.applicationIconBadgeNumber = count }
                        }
                    }
                } else {
                    UIApplication.shared.applicationIconBadgeNumber = count
                }
            }
        }



        private func handleSecretMessage(_ message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  trusted(message.frameInfo.request.url),
                  let body = message.body as? [String: Any],
                  let requestID = body["requestId"] as? String,
                  requestID.range(of: "^[A-Za-z0-9._-]{8,128}$", options: .regularExpression) != nil,
                  let action = body["action"] as? String else { return }

            var response: [String: Any] = ["requestId": requestID, "ok": true]
            switch action {
            case "status":
                response["configured"] = !(SecureOpenAiCredentialStore.read() ?? "").isEmpty
            case "get":
                let key = SecureOpenAiCredentialStore.read() ?? ""
                response["configured"] = !key.isEmpty
                response["key"] = key
            case "set":
                let key = String((body["key"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard key.count >= 20, key.count <= 512, key.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
                    response = ["requestId": requestID, "ok": false, "error": "Invalid OpenAI API key."]
                    break
                }
                if !SecureOpenAiCredentialStore.save(key) {
                    response = ["requestId": requestID, "ok": false, "error": "iOS Keychain rejected the credential."]
                } else {
                    response["configured"] = true
                }
            case "clear":
                SecureOpenAiCredentialStore.clear()
                response["configured"] = false
            default:
                response = ["requestId": requestID, "ok": false, "error": "Unsupported secure credential operation."]
            }
            deliverSecretResponse(response)
        }

        private func deliverSecretResponse(_ response: [String: Any]) {
            guard JSONSerialization.isValidJSONObject(response),
                  let data = try? JSONSerialization.data(withJSONObject: response),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView?.evaluateJavaScript(
                "window.rantlistNativeSecretResult && window.rantlistNativeSecretResult(\(json));",
                completionHandler: nil
            )
        }

        private func jsonLiteral(_ value: Any) -> String? {
            let wrapper: [Any] = [value]
            guard JSONSerialization.isValidJSONObject(wrapper),
                  let data = try? JSONSerialization.data(withJSONObject: wrapper),
                  var string = String(data: data, encoding: .utf8),
                  string.first == "[", string.last == "]" else { return nil }
            string.removeFirst()
            string.removeLast()
            return string
        }

        private func deliverSharedFileError(requestID: String, message: String) {
            guard let requestJSON = jsonLiteral(requestID),
                  let messageJSON = jsonLiteral(message) else { return }
            webView?.evaluateJavaScript(
                "window.rantlistNativeSharedFileError && window.rantlistNativeSharedFileError(\(requestJSON), \(messageJSON));",
                completionHandler: nil
            )
        }

        private func deliverSharedFile(requestID: String, shareID: String, itemID: String) {
            guard requestID.range(of: "^[A-Za-z0-9._-]{8,128}$", options: .regularExpression) != nil,
                  shareID.range(of: "^[A-Fa-f0-9-]{8,64}$", options: .regularExpression) != nil,
                  itemID.range(of: "^[A-Fa-f0-9-]{8,64}$", options: .regularExpression) != nil else {
                deliverSharedFileError(requestID: requestID, message: "The iOS shared-file request was invalid.")
                return
            }
            guard let (fileURL, mime) = NativeShareInbox.fileURL(shareID: shareID, itemID: itemID) else {
                deliverSharedFileError(requestID: requestID, message: "The shared file is no longer available on this iPhone.")
                return
            }
            let name = NativeShareInbox.itemName(shareID: shareID, itemID: itemID) ?? fileURL.lastPathComponent
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                    guard byteCount >= 0, byteCount <= 256 * 1024 * 1024 else {
                        throw NSError(domain: "RantlistShare", code: 11, userInfo: [NSLocalizedDescriptionKey: "This shared file is too large for the native handoff."])
                    }
                    let chunkSize: Int64 = 96 * 1024
                    let total = max(1, Int((byteCount + chunkSize - 1) / chunkSize))
                    let handle = try FileHandle(forReadingFrom: fileURL)
                    defer { try? handle.close() }
                    for index in 0..<total {
                        let chunk = try handle.read(upToCount: Int(chunkSize)) ?? Data()
                        let base64 = chunk.base64EncodedString()
                        DispatchQueue.main.async { [weak self] in
                            guard let self,
                                  let requestJSON = self.jsonLiteral(requestID),
                                  let base64JSON = self.jsonLiteral(base64),
                                  let mimeJSON = self.jsonLiteral(mime),
                                  let nameJSON = self.jsonLiteral(name) else { return }
                            self.webView?.evaluateJavaScript(
                                "window.rantlistNativeSharedFileChunk && window.rantlistNativeSharedFileChunk(\(requestJSON), \(index), \(total), \(base64JSON), \(mimeJSON), \(nameJSON));",
                                completionHandler: nil
                            )
                        }
                    }
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        self?.deliverSharedFileError(requestID: requestID, message: error.localizedDescription)
                    }
                }
            }
        }

        private func deliverNativePushToken() {
            guard shellState.hasLoadedUI,
                  let token = NativeBridgeState.shared.pushToken,
                  let tokenJSON = jsonLiteral(token),
                  let environmentJSON = jsonLiteral(NativeBridgeState.shared.pushEnvironment) else { return }
            webView?.evaluateJavaScript(
                "window.rantlistNativePushToken && window.rantlistNativePushToken(\(tokenJSON), \(environmentJSON));",
                completionHandler: nil
            )
        }

        private func deliverNativeApplicationState(_ explicitState: String? = nil) {
            guard shellState.hasLoadedUI else { return }
            let state: String
            if let explicitState {
                state = explicitState
            } else {
                switch UIApplication.shared.applicationState {
                case .active: state = "active"
                case .background: state = "background"
                case .inactive: state = "inactive"
                @unknown default: state = "inactive"
                }
            }
            guard let stateJSON = jsonLiteral(state) else { return }
            webView?.evaluateJavaScript(
                "window.rantlistNativeAppState && window.rantlistNativeAppState(\(stateJSON));",
                completionHandler: nil
            )
        }

        private func deliverNativeNotificationSettings() {
            guard shellState.hasLoadedUI else { return }
            UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                let authorization: String
                switch settings.authorizationStatus {
                case .authorized: authorization = "authorized"
                case .provisional: authorization = "provisional"
                case .ephemeral: authorization = "ephemeral"
                case .denied: authorization = "denied"
                case .notDetermined: authorization = "notDetermined"
                @unknown default: authorization = "unknown"
                }
                let payload: [String: Any] = [
                    "authorization": authorization,
                    "badgeEnabled": settings.badgeSetting == .enabled,
                ]
                DispatchQueue.main.async {
                    guard let self,
                          self.shellState.hasLoadedUI,
                          let settingsJSON = self.jsonLiteral(payload) else { return }
                    self.webView?.evaluateJavaScript(
                        "window.rantlistNativeNotificationSettings && window.rantlistNativeNotificationSettings(\(settingsJSON));",
                        completionHandler: nil
                    )
                }
            }
        }

        private func deliverPendingShares() {
            guard shellState.hasLoadedUI else { return }
            let payload = NativeShareInbox.pendingPayload()
            guard !payload.isEmpty, let json = jsonLiteral(payload) else { return }
            webView?.evaluateJavaScript(
                "window.rantlistNativeSharedItems && window.rantlistNativeSharedItems(\(json));",
                completionHandler: nil
            )
        }

        private func deliverPendingRoom() {
            guard shellState.hasLoadedUI,
                  let room = NativeBridgeState.shared.pendingRoom,
                  let json = jsonLiteral(room) else { return }
            NativeBridgeState.shared.pendingRoom = nil
            webView?.evaluateJavaScript(
                "window.rantlistNativeOpenRoom && window.rantlistNativeOpenRoom(\(json));",
                completionHandler: nil
            )
        }

        @objc private func pushTokenDidUpdate() { deliverNativePushToken() }
        @objc private func pushBadgeNeedsSync() {
            guard shellState.hasLoadedUI else { return }
            webView?.evaluateJavaScript(
                "window.rantlistNativePushBadgeNeedsSync && window.rantlistNativePushBadgeNeedsSync();",
                completionHandler: nil
            )
        }
        @objc private func sharedInboxDidUpdate() { deliverPendingShares() }
        @objc private func openPendingRoom() { deliverPendingRoom() }

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

        @objc private func applicationWillResignActive() {
            deliverNativeApplicationState("inactive")
        }

        @objc private func applicationDidEnterBackground() {
            deliverNativeApplicationState("background")
        }

        @objc private func applicationDidBecomeActive() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.shellState.hasLoadedUI {
                    self.deliverNativeApplicationState("active")
                    self.deliverNativePushToken()
                    self.deliverNativeNotificationSettings()
                    self.deliverPendingShares()
                    self.deliverPendingRoom()
                } else {
                    self.retryInitialLoad()
                }
            }
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
            deliverNativeApplicationState()
            deliverNativePushToken()
            deliverNativeNotificationSettings()
            deliverPendingShares()
            deliverPendingRoom()
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
