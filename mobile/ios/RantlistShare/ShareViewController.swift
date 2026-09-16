import Foundation
import UIKit
import UniformTypeIdentifiers

private let appGroupIdentifier = "group.fun.workwork.rantlist"
private let shareWebSocketBaseURL = URL(string: "wss://rantlist.me/ws")!
private let nativeShareProtocolVersion = 1

private func makeShareWebSocketURL() -> URL {
    var components = URLComponents(url: shareWebSocketBaseURL, resolvingAgainstBaseURL: false)!
    components.queryItems = [
        URLQueryItem(name: "clientRole", value: "ios-share-extension"),
        URLQueryItem(name: "nativeShareProtocolVersion", value: String(nativeShareProtocolVersion)),
    ]
    return components.url!
}

private struct ShareManifest: Codable {
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

private struct CachedShareSession: Codable {
    struct Participant: Codable {
        let identityId: String
        let nickname: String
        let avatar: String?
        let color: String?
        let status: String?
    }
    struct Room: Codable {
        let roomKey: String
        let name: String
        let direct: Bool?
        let directLabel: String?
        let directParticipants: [Participant]?
        let hidden: Bool?
        let pinned: Bool?
    }
    struct User: Codable {
        let identityId: String
        let nickname: String
        let avatar: String?
        let color: String?
        let status: String?
    }

    let identityId: String
    let nickname: String
    let metadata: [String: String]?
    let uiVersion: String?
    let protocolVersion: Int?
    let rooms: [Room]?
    let users: [User]?
    let savedAt: Double?
}

private struct ShareRecipient: Hashable {
    enum Kind: String { case room, user }
    let kind: Kind
    let id: String
    let roomKey: String?
    let userIdentityId: String?
    let title: String
    let subtitle: String
    let direct: Bool
    let pinned: Bool
    let avatarURL: String?
    let color: String?
}

private enum ShareExtensionError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let value): return value
        }
    }
}

private final class ShareSocketClient {
    private let session: CachedShareSession
    private var webSocket: URLSessionWebSocketTask?
    private var roomsPayload: [[String: Any]]?
    private var usersPayload: [[String: Any]]?
    private var targetsCompletion: ((Result<[ShareRecipient], Error>) -> Void)?
    private var destinationCompletion: ((Result<Void, Error>) -> Void)?
    private var textCompletions: [String: (Result<Void, Error>) -> Void] = [:]
    private var fileCompletions: [String: (Result<Void, Error>) -> Void] = [:]
    private var closed = false
    private let lock = NSLock()

    init(session: CachedShareSession) {
        self.session = session
    }

    func connect(completion: @escaping (Result<[ShareRecipient], Error>) -> Void) {
        lock.lock()
        targetsCompletion = completion
        lock.unlock()

        var request = URLRequest(url: makeShareWebSocketURL())
        request.timeoutInterval = 20
        let socket = URLSession(configuration: .ephemeral).webSocketTask(with: request)
        webSocket = socket
        socket.resume()
        receiveNext()

        let metadata = session.metadata ?? [:]
        sendJSON([
            "type": "hello",
            "identityId": session.identityId,
            "nickname": session.nickname,
            "metadata": metadata.merging(["client": "ios-share-extension", "platform": "iOS"]) { _, new in new },
            "clientRole": "ios-share-extension",
        ]) { [weak self] result in
            if case .failure(let error) = result { self?.failTargets(error) }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 18) { [weak self] in
            self?.failTargets(ShareExtensionError.message("Rantlist took too long to load recipients. Check the connection and try again."))
        }
    }

    func close() {
        lock.lock()
        closed = true
        let socket = webSocket
        webSocket = nil
        lock.unlock()
        socket?.cancel(with: .normalClosure, reason: nil)
    }

    func select(_ recipient: ShareRecipient, completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        destinationCompletion = completion
        lock.unlock()
        var message: [String: Any] = ["type": "native.share.destination"]
        if let roomKey = recipient.roomKey, !roomKey.isEmpty { message["roomKey"] = roomKey }
        else if let identityId = recipient.userIdentityId, !identityId.isEmpty { message["userIdentityId"] = identityId }
        else {
            finishDestination(.failure(ShareExtensionError.message("That Rantlist destination is unavailable.")))
            return
        }
        sendJSON(message) { [weak self] result in
            if case .failure(let error) = result { self?.finishDestination(.failure(error)) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.finishDestination(.failure(ShareExtensionError.message("Rantlist could not open that destination.")))
        }
    }

    func sendText(_ text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { completion(.success(())); return }
        let requestID = UUID().uuidString.replacingOccurrences(of: "-", with: "_")
        lock.lock()
        textCompletions[requestID] = completion
        lock.unlock()
        sendJSON(["type": "native.share.text", "requestId": requestID, "text": String(value.prefix(8000))]) { [weak self] result in
            if case .failure(let error) = result { self?.finishText(requestID, .failure(error)) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.finishText(requestID, .failure(ShareExtensionError.message("The shared text was not confirmed by Rantlist.")))
        }
    }

    func sendFile(url: URL,
                  name: String,
                  mime: String,
                  completion: @escaping (Result<Void, Error>) -> Void) {
        let transferID = UUID().uuidString.replacingOccurrences(of: "-", with: "_")
        let attributes: [FileAttributeKey: Any]
        do { attributes = try FileManager.default.attributesOfItem(atPath: url.path) }
        catch { completion(.failure(error)); return }
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard size > 0 else {
            completion(.failure(ShareExtensionError.message("\(name) is empty and cannot be sent.")))
            return
        }

        lock.lock()
        fileCompletions[transferID] = completion
        lock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let handle = try FileHandle(forReadingFrom: url)
                self.sendFileChunk(handle: handle, transferID: transferID, name: name, mime: mime, size: size, offset: 0)
            } catch {
                self.finishFile(transferID, .failure(error))
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
            self?.finishFile(transferID, .failure(ShareExtensionError.message("Rantlist did not confirm the shared file in time.")))
        }
    }

    private func sendFileChunk(handle: FileHandle,
                               transferID: String,
                               name: String,
                               mime: String,
                               size: Int,
                               offset: Int) {
        guard offset < size else { return }
        let chunkSize = min(128 * 1024, size - offset)
        let chunk: Data
        do { chunk = try handle.read(upToCount: chunkSize) ?? Data() }
        catch { try? handle.close(); finishFile(transferID, .failure(error)); return }
        guard !chunk.isEmpty else {
            try? handle.close()
            finishFile(transferID, .failure(ShareExtensionError.message("Rantlist could not read \(name).")))
            return
        }
        let nextOffset = offset + chunk.count
        let header: [String: Any] = [
            "type": "binary.chunk",
            "transferId": transferID,
            "name": String(name.prefix(180)),
            "mime": mime.isEmpty ? "application/octet-stream" : mime,
            "size": size,
            "kind": "file",
            "caption": "",
            "offset": offset,
            "final": nextOffset == size,
            "target": "room",
        ]
        guard let packet = binaryPacket(header: header, payload: chunk) else {
            try? handle.close()
            finishFile(transferID, .failure(ShareExtensionError.message("Rantlist could not encode \(name).")))
            return
        }
        send(.data(packet)) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                if nextOffset < size {
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.sendFileChunk(handle: handle, transferID: transferID, name: name, mime: mime, size: size, offset: nextOffset)
                    }
                } else {
                    try? handle.close()
                }
            case .failure(let error):
                try? handle.close()
                self.finishFile(transferID, .failure(error))
            }
        }
    }

    private func binaryPacket(header: [String: Any], payload: Data) -> Data? {
        guard JSONSerialization.isValidJSONObject(header),
              let headerData = try? JSONSerialization.data(withJSONObject: header),
              headerData.count > 1, headerData.count <= 8192 else { return nil }
        var length = UInt32(headerData.count).bigEndian
        var packet = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        packet.append(headerData)
        packet.append(payload)
        return packet
    }

    private func sendJSON(_ object: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else {
            completion(.failure(ShareExtensionError.message("Rantlist could not encode the share request.")))
            return
        }
        send(.string(text), completion: completion)
    }

    private func send(_ message: URLSessionWebSocketTask.Message,
                      completion: @escaping (Result<Void, Error>) -> Void) {
        lock.lock()
        let socket = closed ? nil : webSocket
        lock.unlock()
        guard let socket else {
            completion(.failure(ShareExtensionError.message("The Rantlist share connection is closed.")))
            return
        }
        socket.send(message) { error in
            if let error { completion(.failure(error)) }
            else { completion(.success(())) }
        }
    }

    private func receiveNext() {
        lock.lock()
        let socket = closed ? nil : webSocket
        lock.unlock()
        guard let socket else { return }
        socket.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.failAll(error)
            case .success(let message):
                if case .string(let text) = message,
                   let data = text.data(using: .utf8),
                   let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.handleJSON(object)
                }
                self.receiveNext()
            }
        }
    }

    private func handleJSON(_ object: [String: Any]) {
        let type = object["type"] as? String ?? ""
        switch type {
        case "rooms.snapshot":
            roomsPayload = object["rooms"] as? [[String: Any]] ?? []
            maybeFinishTargets()
        case "users.snapshot":
            usersPayload = object["users"] as? [[String: Any]] ?? []
            maybeFinishTargets()
        case "native.share.destination.ready":
            finishDestination(.success(()))
        case "native.share.text.sent":
            if let requestID = object["requestId"] as? String { finishText(requestID, .success(())) }
        case "native.share.file.sent":
            if let transferID = object["transferId"] as? String { finishFile(transferID, .success(())) }
        case "error":
            let message = (object["message"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let error = ShareExtensionError.message(message?.isEmpty == false ? message! : "Rantlist rejected the share request.")
            failCurrentOperation(error)
        case "version.mismatch":
            failAll(ShareExtensionError.message("Rantlist was updated on the server. Update the iOS app and try sharing again."))
        default:
            break
        }
    }

    private func maybeFinishTargets() {
        guard let roomsPayload, let usersPayload else { return }
        var recipients: [ShareRecipient] = []
        for room in roomsPayload {
            guard room["archived"] as? Bool != true,
                  room["readOnly"] as? Bool != true,
                  let roomKey = room["roomKey"] as? String,
                  let name = room["name"] as? String,
                  !roomKey.isEmpty, !name.isEmpty else { continue }
            let direct = room["direct"] as? Bool == true
            if direct {
                let participants = room["directParticipants"] as? [[String: Any]] ?? []
                if let other = participants.first(where: { ($0["identityId"] as? String) != session.identityId }),
                   let identityId = other["identityId"] as? String,
                   !identityId.isEmpty {
                    let nickname = ((other["nickname"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                        ?? ((room["directLabel"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                        ?? "Direct conversation"
                    let metadata = other["metadata"] as? [String: Any] ?? [:]
                    recipients.append(.init(
                        kind: .user,
                        id: identityId,
                        roomKey: roomKey,
                        userIdentityId: nil,
                        title: nickname,
                        subtitle: "Direct conversation",
                        direct: true,
                        pinned: room["pinned"] as? Bool == true,
                        avatarURL: metadata["avatar"] as? String,
                        color: metadata["color"] as? String
                    ))
                }
                continue
            }
            recipients.append(.init(
                kind: .room,
                id: roomKey,
                roomKey: roomKey,
                userIdentityId: nil,
                title: "#\(name)",
                subtitle: (room["private"] as? Bool == true) ? "Private channel" : "Channel",
                direct: false,
                pinned: room["pinned"] as? Bool == true,
                avatarURL: nil,
                color: nil
            ))
        }
        var seenIdentities = Set<String>()
        for user in usersPayload {
            guard let identityId = user["identityId"] as? String,
                  identityId != session.identityId,
                  !seenIdentities.contains(identityId),
                  let nickname = user["nickname"] as? String,
                  !nickname.isEmpty else { continue }
            seenIdentities.insert(identityId)
            let metadata = user["metadata"] as? [String: Any] ?? [:]
            recipients.append(.init(
                kind: .user,
                id: identityId,
                roomKey: nil,
                userIdentityId: identityId,
                title: nickname,
                subtitle: {
                    let status = (metadata["status"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return status.isEmpty ? "Online" : status
                }(),
                direct: true,
                pinned: false,
                avatarURL: metadata["avatar"] as? String,
                color: metadata["color"] as? String
            ))
        }
        lock.lock()
        let completion = targetsCompletion
        targetsCompletion = nil
        lock.unlock()
        completion?(.success(recipients))
    }

    private func failTargets(_ error: Error) {
        lock.lock()
        let completion = targetsCompletion
        targetsCompletion = nil
        lock.unlock()
        completion?(.failure(error))
    }

    private func finishDestination(_ result: Result<Void, Error>) {
        lock.lock()
        let completion = destinationCompletion
        destinationCompletion = nil
        lock.unlock()
        completion?(result)
    }

    private func finishText(_ requestID: String, _ result: Result<Void, Error>) {
        lock.lock()
        let completion = textCompletions.removeValue(forKey: requestID)
        lock.unlock()
        completion?(result)
    }

    private func finishFile(_ transferID: String, _ result: Result<Void, Error>) {
        lock.lock()
        let completion = fileCompletions.removeValue(forKey: transferID)
        lock.unlock()
        completion?(result)
    }

    private func failCurrentOperation(_ error: Error) {
        lock.lock()
        let destination = destinationCompletion
        destinationCompletion = nil
        let text = textCompletions.first
        if let key = text?.key { textCompletions.removeValue(forKey: key) }
        let file = fileCompletions.first
        if let key = file?.key { fileCompletions.removeValue(forKey: key) }
        lock.unlock()
        if let destination { destination(.failure(error)); return }
        if let text { text.value(.failure(error)); return }
        if let file { file.value(.failure(error)); return }
        failTargets(error)
    }

    private func failAll(_ error: Error) {
        failTargets(error)
        finishDestination(.failure(error))
        lock.lock()
        let texts = Array(textCompletions.values)
        let files = Array(fileCompletions.values)
        textCompletions.removeAll()
        fileCompletions.removeAll()
        lock.unlock()
        texts.forEach { $0(.failure(error)) }
        files.forEach { $0(.failure(error)) }
    }
}

final class ShareViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private let titleLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private let searchBar = UISearchBar()
    private let segment = UISegmentedControl(items: ["Channels", "People"])
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let statusLabel = UILabel()
    private let activity = UIActivityIndicatorView(style: .medium)

    private var shareID: String?
    private var manifest: ShareManifest?
    private var manifestDirectory: URL?
    private var shareSession: CachedShareSession?
    private var socketClient: ShareSocketClient?
    private var allRecipients: [ShareRecipient] = []
    private var selectedRecipient: ShareRecipient?
    private var didStart = false
    private var sending = false
    private var recipientServiceReady = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        configureUI()
        loadCachedSessionAndRecipients()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true
        collectSharedItems()
    }

    deinit { socketClient?.close() }

    private func configureUI() {
        titleLabel.text = "Send to"
        titleLabel.textAlignment = .center
        titleLabel.font = .preferredFont(forTextStyle: .headline)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
        cancelButton.addTarget(self, action: #selector(cancelShare), for: .touchUpInside)

        sendButton.setTitle("Send", for: .normal)
        sendButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        sendButton.isEnabled = false
        sendButton.addTarget(self, action: #selector(sendShare), for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [cancelButton, titleLabel, sendButton])
        header.axis = .horizontal
        header.alignment = .center
        header.distribution = .equalCentering
        header.translatesAutoresizingMaskIntoConstraints = false

        searchBar.placeholder = "Search people or channels"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        segment.selectedSegmentIndex = 0
        segment.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        segment.translatesAutoresizingMaskIntoConstraints = false

        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
        tableView.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.numberOfLines = 2
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.text = "Preparing shared item…"

        activity.startAnimating()
        let footer = UIStackView(arrangedSubviews: [activity, statusLabel])
        footer.axis = .horizontal
        footer.alignment = .center
        footer.spacing = 8
        footer.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(header)
        view.addSubview(searchBar)
        view.addSubview(segment)
        view.addSubview(tableView)
        view.addSubview(footer)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            header.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            header.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            header.heightAnchor.constraint(equalToConstant: 36),

            searchBar.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            searchBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),

            segment.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 4),
            segment.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            segment.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.72),

            tableView.topAnchor.constraint(equalTo: segment.bottomAnchor, constant: 6),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -4),

            footer.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            footer.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            footer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            footer.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
        ])
    }

    private func cachedSession() -> CachedShareSession? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else { return nil }
        let url = container
            .appendingPathComponent("Library/Application Support/RantlistShareSession", isDirectory: true)
            .appendingPathComponent("session-v1.json", isDirectory: false)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CachedShareSession.self, from: data)
    }

    private func loadCachedSessionAndRecipients() {
        guard let session = cachedSession() else { return }
        shareSession = session
        var recipients: [ShareRecipient] = []
        for room in session.rooms ?? [] {
            if room.direct == true {
                if let other = room.directParticipants?.first(where: { $0.identityId != session.identityId }) {
                    let title = other.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? ((room.directLabel?.isEmpty == false ? room.directLabel : nil) ?? "Direct conversation")
                        : other.nickname
                    recipients.append(.init(
                        kind: .user,
                        id: other.identityId,
                        roomKey: room.roomKey,
                        userIdentityId: nil,
                        title: title,
                        subtitle: "Direct conversation",
                        direct: true,
                        pinned: room.pinned == true,
                        avatarURL: other.avatar,
                        color: other.color
                    ))
                }
                continue
            }
            recipients.append(.init(
                kind: .room,
                id: room.roomKey,
                roomKey: room.roomKey,
                userIdentityId: nil,
                title: "#\(room.name)",
                subtitle: "Channel",
                direct: false,
                pinned: room.pinned == true,
                avatarURL: nil,
                color: nil
            ))
        }
        for user in session.users ?? [] where user.identityId != session.identityId {
            recipients.append(.init(
                kind: .user,
                id: user.identityId,
                roomKey: nil,
                userIdentityId: user.identityId,
                title: user.nickname,
                subtitle: user.status?.isEmpty == false ? user.status! : "Recent person",
                direct: true,
                pinned: false,
                avatarURL: user.avatar,
                color: user.color
            ))
        }
        allRecipients = deduplicated(recipients)
        tableView.reloadData()
    }

    private func deduplicated(_ recipients: [ShareRecipient]) -> [ShareRecipient] {
        var best: [String: ShareRecipient] = [:]
        for recipient in recipients {
            let key = "\(recipient.kind.rawValue):\(recipient.id)"
            if let existing = best[key] {
                if existing.roomKey == nil && recipient.roomKey != nil { best[key] = recipient }
            } else {
                best[key] = recipient
            }
        }
        return Array(best.values).sorted {
            if $0.pinned != $1.pinned { return $0.pinned && !$1.pinned }
            if $0.direct != $1.direct { return !$0.direct && $1.direct }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private var filteredRecipients: [ShareRecipient] {
        let kind: ShareRecipient.Kind = segment.selectedSegmentIndex == 1 ? .user : .room
        let query = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return allRecipients.filter { recipient in
            guard recipient.kind == kind else { return false }
            guard !query.isEmpty else { return true }
            return recipient.title.localizedCaseInsensitiveContains(query) || recipient.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    private func connectRecipientService() {
        guard let session = shareSession ?? cachedSession() else {
            activity.stopAnimating()
            statusLabel.text = "Open Rantlist once and sign in, then share again."
            return
        }
        shareSession = session
        socketClient?.close()
        recipientServiceReady = false
        sendButton.isEnabled = false
        let client = ShareSocketClient(session: session)
        socketClient = client
        statusLabel.text = "Loading Rantlist destinations…"
        activity.startAnimating()
        client.connect { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let recipients):
                    self.allRecipients = self.deduplicated(recipients)
                    if let selected = self.selectedRecipient, !self.allRecipients.contains(selected) {
                        self.selectedRecipient = nil
                    }
                    self.recipientServiceReady = true
                    self.activity.stopAnimating()
                    self.statusLabel.text = self.allRecipients.isEmpty ? "No available destinations." : "Choose a destination."
                    self.sendButton.isEnabled = self.manifest != nil && self.selectedRecipient != nil
                    self.tableView.reloadData()
                case .failure(let error):
                    self.recipientServiceReady = false
                    self.activity.stopAnimating()
                    self.statusLabel.text = error.localizedDescription
                    self.socketClient?.close()
                    self.socketClient = nil
                    self.tableView.reloadData()
                }
            }
        }
    }

    private func inboxRoot() throws -> URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw ShareExtensionError.message("Rantlist shared storage is unavailable.")
        }
        let root = container.appendingPathComponent("Library/Application Support/RantlistShareInbox", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func safeName(_ value: String?, fallback: String) -> String {
        let raw = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = raw.isEmpty ? fallback : raw
        let clean = candidate.replacingOccurrences(of: "[^A-Za-z0-9._ -]", with: "-", options: .regularExpression)
        return String(clean.prefix(180))
    }

    private func preferredFileType(for provider: NSItemProvider) -> String? {
        provider.registeredTypeIdentifiers.first { identifier in
            guard let type = UTType(identifier) else { return false }
            return type.conforms(to: .image)
                || type.conforms(to: .movie)
                || type.conforms(to: .audio)
                || type.conforms(to: .pdf)
                || type.conforms(to: .archive)
                || type.conforms(to: .data)
                || type.conforms(to: .content)
        }
    }

    private func collectSharedItems() {
        do {
            let id = UUID().uuidString
            shareID = id
            let directory = try inboxRoot().appendingPathComponent(id, isDirectory: true)
            manifestDirectory = directory
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let inputItems = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
            let providers = inputItems.flatMap { $0.attachments ?? [] }
            guard !providers.isEmpty else {
                try? FileManager.default.removeItem(at: directory)
                finishWithError("Nothing shareable was provided.")
                return
            }

            let lock = NSLock()
            var collected: [ShareManifest.Item] = []
            let group = DispatchGroup()
            for provider in providers.prefix(10) {
                group.enter()
                collect(provider: provider, into: directory) { item in
                    if let item { lock.lock(); collected.append(item); lock.unlock() }
                    group.leave()
                }
            }
            group.notify(queue: .main) { [weak self] in
                guard let self else { return }
                do {
                    guard !collected.isEmpty else {
                        try? FileManager.default.removeItem(at: directory)
                        self.finishWithError("The shared item could not be copied into Rantlist.")
                        return
                    }
                    let manifest = ShareManifest(id: id, createdAt: Date().timeIntervalSince1970, items: collected)
                    let data = try JSONEncoder().encode(manifest)
                    try data.write(to: directory.appendingPathComponent("manifest.json"), options: .atomic)
                    self.manifest = manifest
                    self.statusLabel.text = "Loading Rantlist destinations…"
                    self.connectRecipientService()
                } catch {
                    try? FileManager.default.removeItem(at: directory)
                    self.finishWithError(error.localizedDescription)
                }
            }
        } catch {
            finishWithError(error.localizedDescription)
        }
    }

    private func collect(provider: NSItemProvider,
                         into directory: URL,
                         completion: @escaping (ShareManifest.Item?) -> Void) {
        if let typeIdentifier = preferredFileType(for: provider),
           let type = UTType(typeIdentifier),
           !type.conforms(to: .url),
           !type.conforms(to: .plainText) {
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] sourceURL, _ in
                guard let self, let sourceURL else { completion(nil); return }
                let id = UUID().uuidString
                let suggested = provider.suggestedName ?? (sourceURL.lastPathComponent.isEmpty ? "Shared-file" : sourceURL.lastPathComponent)
                let ext = sourceURL.pathExtension.isEmpty ? (type.preferredFilenameExtension ?? "") : sourceURL.pathExtension
                let base = self.safeName((suggested as NSString).deletingPathExtension, fallback: "Shared-file")
                let filename = ext.isEmpty ? "\(id)-\(base)" : "\(id)-\(base).\(ext)"
                let destination = directory.appendingPathComponent(filename)
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: destination)
                    completion(.init(id: id, kind: "file", name: self.safeName(suggested, fallback: filename), mime: type.preferredMIMEType ?? "application/octet-stream", relativePath: filename, text: nil, url: nil))
                } catch { completion(nil) }
            }
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] value, _ in
                guard let self else { completion(nil); return }
                let url: URL?
                if let value = value as? URL { url = value }
                else if let text = value as? String { url = URL(string: text) }
                else if let data = value as? Data, let text = String(data: data, encoding: .utf8) { url = URL(string: text) }
                else { url = nil }
                guard let url else { completion(nil); return }
                if url.isFileURL {
                    let id = UUID().uuidString
                    let filename = "\(id)-\(self.safeName(url.lastPathComponent, fallback: "Shared-file"))"
                    let destination = directory.appendingPathComponent(filename)
                    do {
                        try FileManager.default.copyItem(at: url, to: destination)
                        completion(.init(id: id, kind: "file", name: url.lastPathComponent, mime: "application/octet-stream", relativePath: filename, text: nil, url: nil))
                    } catch { completion(nil) }
                } else {
                    completion(.init(id: UUID().uuidString, kind: "url", name: url.host ?? "Link", mime: "text/uri-list", relativePath: nil, text: nil, url: url.absoluteString))
                }
            }
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { value, _ in
                let text = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !text.isEmpty else { completion(nil); return }
                completion(.init(id: UUID().uuidString, kind: "text", name: "Shared text", mime: "text/plain", relativePath: nil, text: String(text.prefix(12000)), url: nil))
            }
            return
        }
        completion(nil)
    }

    private func finishWithError(_ message: String) {
        activity.stopAnimating()
        statusLabel.text = message
        sendButton.isEnabled = false
    }

    private func preparedText() -> String {
        guard let manifest else { return "" }
        return manifest.items.compactMap { item -> String? in
            if item.kind == "url", let url = item.url, !url.isEmpty { return url }
            if item.kind == "text", let text = item.text, !text.isEmpty { return text }
            return nil
        }.joined(separator: "\n")
    }

    private func fileItems() -> [(ShareManifest.Item, URL)] {
        guard let manifest, let directory = manifestDirectory else { return [] }
        return manifest.items.compactMap { item in
            guard item.kind == "file", let relativePath = item.relativePath, !relativePath.contains("..") else { return nil }
            let url = directory.appendingPathComponent(relativePath).standardizedFileURL
            guard url.path.hasPrefix(directory.standardizedFileURL.path + "/"), FileManager.default.fileExists(atPath: url.path) else { return nil }
            return (item, url)
        }
    }

    private func sendFilesSequentially(_ files: [(ShareManifest.Item, URL)], index: Int = 0) {
        guard index < files.count else { completeSuccessfulShare(); return }
        let (item, url) = files[index]
        socketClient?.sendFile(url: url, name: item.name, mime: item.mime) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.statusLabel.text = "Sending \(index + 1) of \(files.count)…"
                    self.sendFilesSequentially(files, index: index + 1)
                case .failure(let error):
                    self.finishSendingWithError(error.localizedDescription)
                }
            }
        }
    }

    private func completeSuccessfulShare() {
        guard let recipient = selectedRecipient else { return }
        sending = false
        activity.stopAnimating()
        statusLabel.text = "Sent to \(recipient.title)."
        if let directory = manifestDirectory { try? FileManager.default.removeItem(at: directory) }
        socketClient?.close()
        sendButton.isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    private func finishSendingWithError(_ message: String) {
        sending = false
        recipientServiceReady = false
        activity.stopAnimating()
        statusLabel.text = "\(message) Reconnecting…"
        sendButton.isEnabled = false
        tableView.isUserInteractionEnabled = true
        searchBar.isUserInteractionEnabled = true
        segment.isEnabled = true
        socketClient?.close()
        socketClient = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, self.presentingViewController != nil || self.view.window != nil else { return }
            self.connectRecipientService()
        }
    }

    @objc private func cancelShare() {
        if let directory = manifestDirectory { try? FileManager.default.removeItem(at: directory) }
        socketClient?.close()
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    @objc private func sendShare() {
        guard !sending, let recipient = selectedRecipient, let client = socketClient else { return }
        sending = true
        sendButton.isEnabled = false
        tableView.isUserInteractionEnabled = false
        searchBar.resignFirstResponder()
        searchBar.isUserInteractionEnabled = false
        segment.isEnabled = false
        activity.startAnimating()
        statusLabel.text = "Opening \(recipient.title)…"

        client.select(recipient) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .failure(let error):
                    self.finishSendingWithError(error.localizedDescription)
                case .success:
                    let text = self.preparedText()
                    let files = self.fileItems()
                    self.statusLabel.text = files.isEmpty ? "Sending…" : "Sending shared item…"
                    client.sendText(text) { [weak self] textResult in
                        DispatchQueue.main.async {
                            guard let self else { return }
                            switch textResult {
                            case .failure(let error): self.finishSendingWithError(error.localizedDescription)
                            case .success:
                                if files.isEmpty { self.completeSuccessfulShare() }
                                else { self.sendFilesSequentially(files) }
                            }
                        }
                    }
                }
            }
        }
    }

    @objc private func filterChanged() {
        selectedRecipient = nil
        sendButton.isEnabled = false
        tableView.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        tableView.reloadData()
    }

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredRecipients.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuse = "recipient"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuse) ?? UITableViewCell(style: .subtitle, reuseIdentifier: reuse)
        let recipient = filteredRecipients[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = recipient.title
        content.secondaryText = recipient.subtitle
        content.image = UIImage(systemName: recipient.kind == .user ? "person.crop.circle" : (recipient.direct ? "bubble.left.and.bubble.right" : "number"))
        content.imageProperties.tintColor = .systemBlue
        cell.contentConfiguration = content
        cell.accessoryType = selectedRecipient == recipient ? .checkmark : .none
        cell.selectionStyle = .default
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let recipient = filteredRecipients[indexPath.row]
        selectedRecipient = recipient
        sendButton.isEnabled = manifest != nil && recipientServiceReady
        tableView.reloadData()
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
