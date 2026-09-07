import Darwin
import Foundation

final class CodexClient {
    static let shared = CodexClient()
    private let queue = DispatchQueue(label: "soli.Cloude.codex.protocol")
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var nextId = 0
    private var lineBuffer = Data()
    private var initialized = false
    private var starting = false
    private var startup: [(Result<Void, Error>) -> Void] = []
    private var pending: [Int: (Result<[String: Any], Error>) -> Void] = [:]
    private var generationPending: [Int: (threadId: String, turnId: String?)] = [:]
    private var activityId: UUID?
    private var authMode: String?
    private var authenticationKnown = false
    private var authRevision = 0
    private var accountReads: [Int: Int] = [:]
    private var activeTurns: [String: String] = [:]
    private var serverRequests: [String: (id: Any, method: String, params: [String: Any])] = [:]
    private var parents: [String: String] = [:]
    private var owners: [String: String] = [:]
    private var observers: [String: (DispatchQueue, ([String: Any]) -> Void, (Error) -> Void)] = [:]
    private let executablePath: String
    private let requestTimeout: TimeInterval
    var hasPendingWork: Bool {
        queue.sync { !pending.isEmpty || !serverRequests.isEmpty || starting || !activeTurns.isEmpty }
    }

    init(executablePath: String? = nil, requestTimeout: TimeInterval = 20) {
        self.executablePath = executablePath ?? Self.executable()
        self.requestTimeout = requestTimeout
    }

    func isThreadActive(threadId: String) -> Bool {
        queue.sync { activeTurns[threadId] != nil }
    }

    func stop() {
        queue.async { self.disconnect(Self.error("Codex connection stopped")) }
    }

    func settleGenerationStarts(threadId: String) {
        queue.async {
            let ids = self.generationPending.compactMap { $0.value.threadId == threadId ? $0.key : nil }
            ids.forEach {
                self.generationPending.removeValue(forKey: $0)
                self.pending.removeValue(forKey: $0)?(.failure(Self.error("Codex turn settled from its event stream")))
            }
        }
    }

    func observe(
        id: String, on queue: DispatchQueue, message: @escaping ([String: Any]) -> Void,
        disconnected: @escaping (Error) -> Void
    ) {
        self.queue.async { self.observers[id] = (queue, message, disconnected) }
    }

    func removeObserver(id: String) {
        queue.async { self.observers.removeValue(forKey: id) }
    }

    func request(
        _ method: String, params: [String: Any] = [:], replyOn: DispatchQueue = .global(),
        timeout: TimeInterval? = nil,
        noTimeout: Bool = false,
        onSent: (() -> Void)? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let admission = DaemonLifecycle.shared.begin() else {
            replyOn.async {
                completion(.failure(Self.error("The daemon is restarting for an update. Reconnect and retry.")))
            }
            return
        }
        queue.async {
            let complete: (Result<[String: Any], Error>) -> Void = { result in
                DaemonLifecycle.shared.end(admission)
                replyOn.async { completion(result) }
            }
            if self.initialized {
                self.sendRequest(
                    method, params: params, timeout: noTimeout ? nil : timeout ?? self.requestTimeout,
                    sent: { if let onSent { replyOn.async(execute: onSent) } }, completion: complete)
            } else {
                self.startup.append { result in
                    switch result {
                    case .success:
                        self.sendRequest(
                            method, params: params, timeout: noTimeout ? nil : timeout ?? self.requestTimeout,
                            sent: { if let onSent { replyOn.async(execute: onSent) } }, completion: complete)
                    case .failure(let error): complete(.failure(error))
                    }
                }
                if !self.starting { self.start() }
            }
        }
    }

    func pendingRequests(threadId: String) -> [[String: Any]] {
        queue.sync {
            serverRequests.compactMap { key, request in
                request.params["threadId"] as? String == threadId
                    ? ["requestId": key, "method": request.method, "params": request.params] : nil
            }
        }
    }

    func pendingKey(id: Any, threadId: String) -> String? {
        queue.sync {
            serverRequests.first {
                $0.value.params["threadId"] as? String == threadId && Self.sameId($0.value.id, id)
            }?.key
        }
    }

    func respond(requestId: String, threadId: String, result: [String: Any]) -> Bool {
        queue.sync {
            if !authenticationKnown || authMode == "chatgpt", let request = serverRequests[requestId],
                request.params["threadId"] as? String == threadId
            {
                var response = result
                if request.method == "item/permissions/requestApproval", let decision = result["decision"] as? String {
                    response = [
                        "permissions": decision == "accept" || decision == "acceptForSession"
                            ? request.params["permissions"] as Any? ?? [:] : [:],
                        "scope": decision == "acceptForSession" ? "session" : "turn",
                    ]
                }
                if write(["id": request.id, "result": response]) {
                    serverRequests.removeValue(forKey: requestId)
                    refreshActivity()
                    notify([
                        "method": "serverRequest/resolved",
                        "params": [
                            "threadId": threadId, "requestId": request.id, "requestKey": requestId,
                        ],
                    ])
                    return true
                }
            }
            return false
        }
    }

    func registerOwner(threadId: String, sessionId: String) {
        queue.sync {
            if self.owners[threadId] != sessionId {
                self.owners[threadId] = sessionId
                self.reannounceRequests()
            }
        }
    }

    func unregisterOwner(threadId: String, sessionId: String) {
        queue.sync {
            if self.owners[threadId] == sessionId { self.owners.removeValue(forKey: threadId) }
            self.reannounceRequests()
        }
    }

    func ownerForThread(_ threadId: String) -> (threadId: String, sessionId: String)? {
        queue.sync { owner(for: threadId) }
    }

    func attentionForThread(_ threadId: String) -> [[String: Any]] {
        queue.sync {
            serverRequests.compactMap { key, request in
                guard let child = request.params["threadId"] as? String, child != threadId,
                    owner(for: child)?.threadId == threadId, isDescendant(child, of: threadId)
                else { return nil }
                return ["threadId": child, "requestId": key]
            }
        }
    }

    private static func sameId(_ left: Any, _ right: Any) -> Bool {
        (try? JSONSerialization.data(withJSONObject: [left])) == (try? JSONSerialization.data(withJSONObject: [right]))
    }

    private func start() {
        starting = true
        let child = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        child.executableURL = URL(fileURLWithPath: executablePath)
        child.arguments = ["app-server", "--listen", "stdio://"]
        child.standardInput = stdin
        child.standardOutput = stdout
        child.standardError = stderr
        child.environment = Self.environment()
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                self?.queue.async { if self?.process === child { self?.receive(data) } }
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            if handle.availableData.isEmpty { handle.readabilityHandler = nil }
        }
        child.terminationHandler = { [weak self] child in
            self?.queue.async {
                if self?.process === child {
                    self?.disconnect(Self.error("Codex app-server exited (\(child.terminationStatus))"))
                }
            }
        }
        switch Result(catching: { try child.run() }) {
        case .success:
            process = child
            input = stdin.fileHandleForWriting
            output = stdout.fileHandleForReading
            sendRequest(
                "initialize",
                params: [
                    "clientInfo": ["name": "afto_macos", "version": "1.0.0"],
                    "capabilities": ["experimentalApi": true],
                ], timeout: self.requestTimeout
            ) { result in
                switch result {
                case .success:
                    self.initialized = true
                    self.starting = false
                    self.write(["method": "initialized", "params": [:]])
                    let waiting = self.startup
                    self.startup.removeAll()
                    waiting.forEach { $0(.success(())) }
                case .failure(let error): self.disconnect(error)
                }
            }
        case .failure(let error): disconnect(error)
        }
    }

    private func sendRequest(
        _ method: String, params: [String: Any], timeout: TimeInterval?,
        sent: (() -> Void)? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        if ["turn/start", "review/start", "turn/steer", "thread/compact/start"].contains(method), authenticationKnown,
            authMode != "chatgpt"
        {
            completion(
                .failure(
                    Self.error("Codex authentication changed. Sign in with a ChatGPT subscription before continuing.")))
            return
        }
        if ["turn/start", "review/start", "thread/shellCommand"].contains(method),
            let threadId = params["threadId"] as? String, activeTurns[threadId] != nil
        {
            completion(
                .failure(Self.error("This task is running on the host. Wait for it to finish before continuing.")))
            return
        }
        nextId += 1
        let id = nextId
        if method == "account/read" { accountReads[id] = authRevision }
        pending[id] = completion
        if ["turn/start", "review/start", "thread/shellCommand"].contains(method),
            let threadId = params["threadId"] as? String
        {
            generationPending[id] = (threadId, nil)
        }
        if let timeout {
            queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.generationPending.removeValue(forKey: id)
                self?.accountReads.removeValue(forKey: id)
                self?.pending.removeValue(forKey: id)?(.failure(Self.error("Codex \(method) timed out")))
            }
        }
        if write(["id": id, "method": method, "params": params]) { sent?() }
    }

    @discardableResult
    private func write(_ message: [String: Any]) -> Bool {
        if let input, let data = try? JSONSerialization.data(withJSONObject: message) {
            if (try? input.write(contentsOf: data + Data([0x0A]))) != nil { return true }
            disconnect(Self.error("Codex connection closed"))
        } else {
            disconnect(Self.error("Codex connection is unavailable"))
        }
        return false
    }

    private func receive(_ data: Data) {
        lineBuffer.append(data)
        if lineBuffer.count > 32 * 1024 * 1024 {
            disconnect(Self.error("Codex protocol message exceeded the size limit"))
        } else {
            while let newline = lineBuffer.firstIndex(of: 0x0A) {
                let line = lineBuffer.subdata(in: 0..<newline)
                lineBuffer.removeSubrange(0...newline)
                if let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] {
                    if let method = object["method"] as? String {
                        if method == "account/updated" {
                            authenticationKnown = true
                            authMode = (object["params"] as? [String: Any])?["authMode"] as? String
                            authRevision += 1
                        }
                        if let params = object["params"] as? [String: Any], let threadId = params["threadId"] as? String
                        {
                            if method == "turn/started",
                                let turnId = (params["turn"] as? [String: Any])?["id"] as? String
                            {
                                activeTurns[threadId] = turnId
                                for id in generationPending.keys
                                where generationPending[id]?.threadId == threadId
                                    && generationPending[id]?.turnId == nil
                                {
                                    generationPending[id]?.turnId = turnId
                                }
                            }
                            if ["thread/closed", "thread/archived", "thread/deleted"].contains(method) {
                                activeTurns.removeValue(forKey: threadId)
                            } else if method == "turn/completed",
                                let turnId = (params["turn"] as? [String: Any])?["id"] as? String,
                                activeTurns[threadId] == turnId
                            {
                                activeTurns.removeValue(forKey: threadId)
                            }
                        }
                        var notification = object
                        if method == "thread/started", let thread = object["params"] as? [String: Any],
                            let value = thread["thread"] as? [String: Any], let child = value["id"] as? String
                        {
                            let parent =
                                value["parentThreadId"] as? String
                                ?? ((value["source"] as? [String: Any])?["subAgent"] as? [String: Any])
                                .flatMap { ($0["thread_spawn"] as? [String: Any])?["parent_thread_id"] as? String }
                            linkParent(child, parent)
                        }
                        if method == "item/completed", let params = object["params"] as? [String: Any],
                            let item = params["item"] as? [String: Any],
                            item["type"] as? String == "collabAgentToolCall",
                            item["tool"] as? String == "spawnAgent", let parent = params["threadId"] as? String
                        {
                            (item["receiverThreadIds"] as? [String] ?? []).forEach { linkParent($0, parent) }
                        }
                        if ["item/started", "item/completed"].contains(method),
                            let params = object["params"] as? [String: Any],
                            let item = params["item"] as? [String: Any],
                            item["type"] as? String == "subAgentActivity",
                            let parent = params["threadId"] as? String,
                            let child = item["agentThreadId"] as? String
                        {
                            linkParent(child, parent)
                        }
                        if let id = object["id"], let params = object["params"] as? [String: Any],
                            let threadId = params["threadId"] as? String
                        {
                            serverRequests = serverRequests.filter {
                                $0.value.params["threadId"] as? String != threadId || !Self.sameId($0.value.id, id)
                            }
                            if serverRequests.count >= 256 {
                                disconnect(Self.error("Too many Codex requests are waiting for a response"))
                                return
                            }
                            let key = UUID().uuidString.lowercased()
                            serverRequests[key] = (id, method, params)
                            notification["params"] = params.merging(["requestKey": key]) { _, latest in latest }
                        } else if let params = object["params"] as? [String: Any],
                            let threadId = params["threadId"] as? String
                        {
                            if method == "serverRequest/resolved", let id = params["requestId"] {
                                if let key = serverRequests.first(where: {
                                    $0.value.params["threadId"] as? String == threadId && Self.sameId($0.value.id, id)
                                })?.key {
                                    serverRequests.removeValue(forKey: key)
                                    notification["params"] = params.merging(["requestKey": key]) { _, latest in latest }
                                }
                            }
                            if ["thread/closed", "thread/archived", "thread/deleted"].contains(method)
                                || (method == "turn/completed"
                                    && (activeTurns[threadId] == nil
                                        || activeTurns[threadId] == (params["turn"] as? [String: Any])?["id"] as? String))
                            {
                                let resolved = serverRequests.filter {
                                    $0.value.params["threadId"] as? String == threadId
                                }
                                serverRequests = serverRequests.filter {
                                    $0.value.params["threadId"] as? String != threadId
                                }
                                resolved.forEach { key, request in
                                    notify([
                                        "method": "serverRequest/resolved",
                                        "params": [
                                            "threadId": threadId, "requestId": request.id, "requestKey": key,
                                        ],
                                    ])
                                }
                            }
                        }
                        refreshActivity()
                        notify(notification)
                        if method == "turn/completed", let params = object["params"] as? [String: Any],
                            let threadId = params["threadId"] as? String,
                            let turnId = (params["turn"] as? [String: Any])?["id"] as? String
                        {
                            for id in Array(generationPending.keys)
                            where generationPending[id]?.threadId == threadId && generationPending[id]?.turnId == turnId
                            {
                                generationPending.removeValue(forKey: id)
                                pending.removeValue(forKey: id)?(
                                    .failure(Self.error("Codex turn settled from its event stream")))
                            }
                        }
                    } else if let id = object["id"] as? Int, let callback = pending.removeValue(forKey: id) {
                        generationPending.removeValue(forKey: id)
                        if let revision = accountReads.removeValue(forKey: id), revision == authRevision,
                            object["error"] == nil
                        {
                            authenticationKnown = true
                            authMode =
                                ((object["result"] as? [String: Any])?["account"] as? [String: Any])?["type"] as? String
                        }
                        if let error = object["error"] as? [String: Any] {
                            callback(.failure(Self.error(error["message"] as? String ?? "Codex request failed")))
                        } else {
                            callback(.success(object["result"] as? [String: Any] ?? [:]))
                        }
                    }
                } else {
                    disconnect(Self.error("Codex sent invalid protocol data"))
                }
            }
        }
    }

    private func disconnect(_ error: Error) {
        if process == nil, !starting, startup.isEmpty, pending.isEmpty { return }
        initialized = false
        starting = false
        output?.readabilityHandler = nil
        try? input?.close()
        if let child = process {
            child.terminationHandler = nil
            (child.standardError as? Pipe)?.fileHandleForReading.readabilityHandler = nil
            if child.isRunning {
                child.terminate()
                queue.asyncAfter(deadline: .now() + 2) {
                    if child.isRunning { Darwin.kill(child.processIdentifier, SIGKILL) }
                }
            }
        }
        process = nil
        input = nil
        output = nil
        lineBuffer.removeAll()
        let waiting = startup
        let requests = Array(pending.values)
        let resolved = serverRequests.map { key, request in
            [
                "method": "serverRequest/resolved",
                "params": [
                    "threadId": request.params["threadId"] as Any, "requestId": request.id, "requestKey": key,
                ],
            ] as [String: Any]
        }
        startup.removeAll()
        pending.removeAll()
        generationPending.removeAll()
        serverRequests.removeAll()
        activeTurns.removeAll()
        refreshActivity()
        accountReads.removeAll()
        authenticationKnown = false
        authMode = nil
        authRevision += 1
        parents.removeAll()
        owners.removeAll()
        waiting.forEach { $0(.failure(error)) }
        requests.forEach { $0(.failure(error)) }
        resolved.forEach(notify)
        for (queue, _, callback) in observers.values { queue.async { callback(error) } }
    }

    private func refreshActivity() {
        if activeTurns.isEmpty && serverRequests.isEmpty {
            if let activityId {
                DaemonLifecycle.shared.end(activityId)
                self.activityId = nil
            }
        } else if activityId == nil {
            activityId = DaemonLifecycle.shared.observeWork()
        }
    }

    private func linkParent(_ child: String, _ parent: String?) {
        guard let parent, !child.isEmpty, !parent.isEmpty, child != parent else { return }
        if parents[child] != parent {
            parents[child] = parent
            reannounceRequests()
        }
    }

    private func owner(for threadId: String) -> (threadId: String, sessionId: String)? {
        var current: String? = threadId
        var visited: Set<String> = []
        while let value = current, visited.insert(value).inserted {
            if let sessionId = owners[value] { return (value, sessionId) }
            current = parents[value]
        }
        return nil
    }

    private func isDescendant(_ child: String, of parent: String) -> Bool {
        var current: String? = child
        var visited: Set<String> = []
        while let value = current, visited.insert(value).inserted {
            current = parents[value]
            if current == parent { return true }
        }
        return false
    }

    private func reannounceRequests() {
        for request in serverRequests.values {
            notify(["method": request.method, "id": request.id, "params": request.params])
        }
    }

    private func notify(_ message: [String: Any]) {
        for (queue, callback, _) in observers.values { queue.async { callback(message) } }
    }

    private static func error(_ message: String) -> Error {
        NSError(domain: "Codex", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func executable() -> String {
        ProcessInfo.processInfo.environment["CLOUDE_CODEX_BIN"] ?? [
            "/Applications/ChatGPT.app/Contents/Resources/codex", "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex",
        ].first(where: FileManager.default.isExecutableFile(atPath:)) ?? "/usr/local/bin/codex"
    }

    private static func environment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment.filter {
            [
                "HOME", "USER", "SHELL", "LANG", "LC_ALL", "TMPDIR", "TERM", "PATH", "CODEX_HOME", "SSH_AUTH_SOCK",
                "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "SSL_CERT_FILE", "SSL_CERT_DIR",
            ].contains($0.key)
        }
        environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        environment["PATH"] = (environment["PATH"] ?? "/usr/bin:/bin") + ":/opt/homebrew/bin:/usr/local/bin"
        return environment
    }
}
