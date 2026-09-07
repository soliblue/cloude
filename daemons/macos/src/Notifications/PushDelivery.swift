import Foundation

final class PushDelivery {
    static let shared = PushDelivery()
    static let expiration: TimeInterval = 86_400

    private let queue = DispatchQueue(label: "soli.Cloude.push", qos: .utility)
    private let directory: URL
    private let file: URL
    private let transport: (URLRequest, @escaping (Result<Int, Error>) -> Void) -> Void
    private let hostProvider: () -> String?
    private let identityProvider: () -> RemoteTunnelIdentity
    private var entries: [String: PushEntry] = [:]
    private var timer: DispatchSourceTimer?
    private var flushing = false

    init(
        directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Remote CC", isDirectory: true),
        session: URLSession = .shared,
        transport: ((URLRequest, @escaping (Result<Int, Error>) -> Void) -> Void)? = nil,
        hostProvider: @escaping () -> String? = { RemoteTunnelCredentialStore.tunnelHost },
        identityProvider: @escaping () -> RemoteTunnelIdentity = { RemoteTunnelCredentialStore.identity }
    ) {
        self.directory = directory
        file = directory.appendingPathComponent("push-queue.json")
        self.hostProvider = hostProvider
        self.identityProvider = identityProvider
        self.transport =
            transport ?? { request, completion in
                session.dataTask(with: request) { _, response, error in
                    if let error {
                        completion(.failure(error))
                    } else {
                        completion(.success((response as? HTTPURLResponse)?.statusCode ?? 599))
                    }
                }.resume()
            }
        restore()
    }

    var available: Bool { hostProvider() != nil }

    func start() {
        queue.async {
            self.flushLocked()
            if self.timer == nil {
                let timer = DispatchSource.makeTimerSource(queue: self.queue)
                timer.schedule(deadline: .now() + 30, repeating: 30)
                timer.setEventHandler { [weak self] in self?.flushLocked() }
                timer.resume()
                self.timer = timer
            }
        }
    }

    func enqueueNotification(
        sessionId: String, title: String, body: String, kind: String, eventId: String = UUID().uuidString.lowercased()
    ) {
        enqueue(
            key: "notification:\(eventId)", method: "POST", route: "/notifications",
            body: ["sessionId": sessionId, "title": title, "body": body, "kind": kind, "eventId": eventId])
    }

    func register(deviceId: String, token: String, environment: String) {
        enqueue(
            key: "device:\(deviceId)", method: "PUT", route: "/push-devices/\(deviceId)",
            body: ["deviceId": deviceId, "token": token, "environment": environment, "bundleId": "soli.Cloude"])
    }

    func cancelNotification(eventId: String) {
        queue.async {
            self.entries = self.entries.filter { $0.value.body["eventId"] != eventId }
            self.persistLocked()
        }
    }

    func flushNow() { queue.async { self.flushLocked() } }

    private func enqueue(key: String, method: String, route: String, body: [String: String]) {
        queue.async {
            guard self.available else { return }
            if method == "POST", self.entries.values.contains(where: { $0.body["eventId"] == body["eventId"] }) {
                return
            }
            self.entries[key] = PushEntry(
                id: UUID().uuidString.lowercased(), method: method, route: route, body: body, createdAt: Date())
            self.persistLocked()
            self.flushLocked()
        }
    }

    private func restore() {
        queue.sync {
            guard let data = try? Data(contentsOf: file),
                let decoded = try? JSONDecoder().decode([String: PushEntry].self, from: data),
                decoded.values.allSatisfy(valid)
            else {
                quarantineLocked()
                return
            }
            entries = decoded.filter {
                Date().timeIntervalSince($0.value.createdAt) >= 0
                    && Date().timeIntervalSince($0.value.createdAt) <= Self.expiration
            }
            if entries.count != decoded.count { persistLocked() }
        }
    }

    private func valid(_ entry: PushEntry) -> Bool {
        guard entry.id.count <= 64, !entry.body.isEmpty else { return false }
        if entry.method == "POST" {
            return entry.route == "/notifications"
                && ["completed", "failed", "attention"].contains(entry.body["kind"] ?? "")
                && entry.body["sessionId"]?.isEmpty == false && entry.body["eventId"]?.isEmpty == false
        }
        return entry.method == "PUT" && entry.route.hasPrefix("/push-devices/")
            && entry.body["bundleId"] == "soli.Cloude"
    }

    private func persistLocked() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: file, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    private func quarantineLocked() {
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        let target = file.deletingLastPathComponent().appendingPathComponent("push-queue.corrupt-\(UUID().uuidString)")
        try? FileManager.default.moveItem(at: file, to: target)
    }

    private func flushLocked() {
        guard !flushing, available, !entries.isEmpty else { return }
        flushing = true
        let ordered = entries.sorted { ($0.value.method == "PUT" ? 0 : 1) < ($1.value.method == "PUT" ? 0 : 1) }
        send(ordered, index: 0) { [weak self] in self?.flushing = false }
    }

    private func send(_ ordered: [(key: String, value: PushEntry)], index: Int, done: @escaping () -> Void) {
        guard index < ordered.count else {
            done()
            return
        }
        let pair = ordered[index]
        guard entries[pair.key]?.id == pair.value.id else {
            send(ordered, index: index + 1, done: done)
            return
        }
        guard let host = hostProvider() else {
            done()
            return
        }
        let identity = identityProvider()
        let url = URL(string: "https://\(host)/macs/\(identity.macInstallationId)\(pair.value.route)")!
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = pair.value.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(identity.macSecret, forHTTPHeaderField: "X-Mac-Secret")
        var payload = pair.value.body
        payload["eventId"] = pair.value.body["eventId"] ?? pair.value.id
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        transport(request) { result in
            self.queue.async {
                let current = self.entries[pair.key]
                let expired = Date().timeIntervalSince(pair.value.createdAt) > Self.expiration
                let status = try? result.get()
                let delivered = status.map { (200..<300).contains($0) || $0 == 410 } == true
                if current?.id == pair.value.id && (delivered || expired) {
                    self.entries.removeValue(forKey: pair.key)
                    self.persistLocked()
                }
                let accepted = status.map { (200..<300).contains($0) } == true
                if pair.value.method == "PUT", !accepted {
                    done()
                } else {
                    self.send(ordered, index: index + 1, done: done)
                }
            }
        }
    }
}
