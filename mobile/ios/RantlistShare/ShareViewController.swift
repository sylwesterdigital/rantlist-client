import UIKit
import UniformTypeIdentifiers

private let appGroupIdentifier = "group.fun.workwork.rantlist"

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

final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let openButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private var shareID: String?
    private var didStart = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.text = "Preparing items for Rantlist…"
        statusLabel.font = .preferredFont(forTextStyle: .body)

        openButton.setTitle("Open Rantlist", for: .normal)
        openButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        openButton.isEnabled = false
        openButton.addTarget(self, action: #selector(openRantlist), for: .touchUpInside)

        doneButton.setTitle("Done", for: .normal)
        doneButton.addTarget(self, action: #selector(done), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [statusLabel, openButton, doneButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true
        collectSharedItems()
    }

    private func inboxRoot() throws -> URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw NSError(domain: "RantlistShare", code: 1, userInfo: [NSLocalizedDescriptionKey: "Rantlist shared storage is unavailable."])
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
                    if let item {
                        lock.lock(); collected.append(item); lock.unlock()
                    }
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
                    self.statusLabel.text = collected.count == 1
                        ? "1 item is ready. Open Rantlist, choose the channel or private conversation, then tap Send shared item."
                        : "\(collected.count) items are ready. Open Rantlist, choose the channel or private conversation, then tap Send shared items."
                    self.openButton.isEnabled = true
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
                let suggested = provider.suggestedName
                    ?? (sourceURL.lastPathComponent.isEmpty ? "Shared-file" : sourceURL.lastPathComponent)
                let ext = sourceURL.pathExtension.isEmpty ? (type.preferredFilenameExtension ?? "") : sourceURL.pathExtension
                let base = self.safeName((suggested as NSString).deletingPathExtension, fallback: "Shared-file")
                let filename = ext.isEmpty ? "\(id)-\(base)" : "\(id)-\(base).\(ext)"
                let destination = directory.appendingPathComponent(filename)
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: destination)
                    completion(.init(
                        id: id,
                        kind: "file",
                        name: self.safeName(suggested, fallback: filename),
                        mime: type.preferredMIMEType ?? "application/octet-stream",
                        relativePath: filename,
                        text: nil,
                        url: nil
                    ))
                } catch { completion(nil) }
            }
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { value, _ in
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
        statusLabel.text = message
        openButton.isEnabled = false
    }

    @objc private func openRantlist() {
        guard let shareID,
              let url = URL(string: "rantlist://share?id=\(shareID)") else { return }
        extensionContext?.open(url) { [weak self] opened in
            DispatchQueue.main.async {
                if opened {
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                } else {
                    self?.statusLabel.text = "The item is saved. Open Rantlist manually, choose the destination, then tap Send shared item."
                }
            }
        }
    }

    @objc private func done() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
