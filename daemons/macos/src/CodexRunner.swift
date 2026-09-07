import CryptoKit
import Foundation
import Network

final class CodexRunner: Runner {
    private(set) var threadId: String?
    private let codex: CodexClient
    private let steerReceipts: CodexSteerReceiptStore
    private let reviewTarget: [String: Any]?
    private let shellCommand: String?
    private var reviewHash = SHA256()
    private var reviewMessages: Set<Data> = []
    private let deliveryQueue: DispatchQueue
    private var turnId: String?
    private var cancelled = false
    private var interruptRequested = false
    private let journal: CodexJournal?
    private var journalFailed = false
    private var reportingStorageFailure = false
    private let skills: [[String: String]]
    private let mentions: [[String: String]]
    private let projectId: String?
    private var heartbeat: DispatchSourceTimer?
    private var requests: [String: (id: Any, method: String, params: [String: Any])] = [:]
    private var workingPath: String?
    private var steerHashes: [String: String] = [:]
    private var steerResults: [String: Result<[String: Any], Error>] = [:]
    private var steerWaiters: [String: [(Result<[String: Any], Error>) -> Void]] = [:]

    init(
        sessionId: String, hasStartedBefore: Bool, model: String?, effort: String?, permissionMode: String?,
        threadId: String?, skills: [[String: String]] = [], mentions: [[String: String]] = [], projectId: String? = nil,
        reviewTarget: [String: Any]? = nil, shellCommand: String? = nil, codex: CodexClient = .shared,
        steerReceipts: CodexSteerReceiptStore = .shared,
        queue: DispatchQueue
    ) {
        self.threadId = threadId
        self.reviewTarget = reviewTarget
        self.shellCommand = shellCommand
        self.codex = codex
        self.steerReceipts = steerReceipts
        self.skills = skills
        self.mentions = mentions
        self.projectId = projectId
        journal = CodexJournal(sessionId: sessionId, reset: true)
        deliveryQueue = queue
        super.init(
            sessionId: sessionId, hasStartedBefore: hasStartedBefore, model: model, effort: effort,
            permissionMode: permissionMode, queue: queue)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 20, repeating: 20)
        timer.setEventHandler { [weak self] in self?.emit(["type": "heartbeat"]) }
        heartbeat = timer
        timer.resume()
    }

    override func spawn(path: String, prompt: String, images: [[String: String]] = []) {
        workingPath = path
        if let reviewTarget, !CodexReviewTarget.valid(reviewTarget) {
            fail("Invalid Codex review target.")
            return
        }
        if let shellCommand,
            !CodexShellCommand.valid(shellCommand) || reviewTarget != nil || !images.isEmpty || !skills.isEmpty
                || !mentions.isEmpty
        {
            fail("Provide a command without images, references or a review target.")
            return
        }
        if journal == nil {
            fail("The daemon cannot save this conversation. Check available disk space and storage permissions.")
            return
        }
        if threadId == nil { threadId = CodexSessionStore.shared.threadId(for: sessionId) }
        codex.observe(
            id: sessionId, on: deliveryQueue,
            message: { [weak self] message in
                if let self, let method = message["method"] as? String,
                    let params = message["params"] as? [String: Any],
                    params["threadId"] as? String == self.threadId || method == "account/updated", !self.hasExited
                {
                    if let id = message["id"], let threadId = self.threadId,
                        let key = self.codex.pendingKey(id: id, threadId: threadId)
                    {
                        self.requests[key] = (id, method, params)
                        PushDelivery.shared.enqueueNotification(
                            sessionId: self.sessionId,
                            title: "Approval needed",
                            body: "Open the task to continue your agent.",
                            kind: "attention",
                            eventId: "attention:\(self.sessionId):\(key)")
                        self.emit(["type": "request", "requestId": key, "method": method, "params": params])
                    } else {
                        self.receive(method: method, params: params)
                    }
                }
            }, disconnected: { [weak self] error in self?.fail(error.localizedDescription) })
        let group = DispatchGroup()
        var responses: [String: [String: Any]] = [:]
        var failure: String?
        for method in ["account/read", "config/read"] + (shellCommand == nil ? ["account/rateLimits/read"] : []) {
            group.enter()
            codex.request(
                method, params: method == "config/read" ? ["cwd": path, "includeLayers": false] : [:],
                replyOn: deliveryQueue
            ) { result in
                switch result {
                case .success(let value): responses[method] = value
                case .failure(let error): failure = error.localizedDescription
                }
                group.leave()
            }
        }
        group.notify(queue: deliveryQueue) { [weak self] in
            if let self, !self.hasExited {
                if let error = failure
                    ?? CodexSubscriptionPolicy.rejection(
                        account: responses["account/read"] ?? [:], config: responses["config/read"] ?? [:],
                        limits: responses["account/rateLimits/read"] ?? [:], requireCapacity: self.shellCommand == nil)
                {
                    self.fail(error)
                } else if self.cancelled {
                    self.finish(exitCode: 0)
                } else {
                    self.begin(path: path, prompt: prompt, images: images)
                }
            }
        }
    }

    override func record(_ data: Data, seq: Int) -> Bool {
        if reportingStorageFailure { return true }
        if journalFailed { return false }
        if journal?.append(data, seq: seq) == false {
            journalFailed = true
            deliveryQueue.async {
                self.reportingStorageFailure = true
                self.abort()
                self.fail("The daemon could not save streamed output. Check available disk space before continuing.")
                self.reportingStorageFailure = false
            }
            return false
        }
        return true
    }

    override func subscribe(_ connection: NWConnection, afterSeq: Int = -1) {
        if let journal, journal.lastSeq > afterSeq, let reader = journal.reader(afterSeq: afterSeq) {
            CodexJournalReplay(reader: reader, connection: connection, queue: deliveryQueue) { [self] reader in
                subscribe(connection, afterSeq: reader.lastSeq)
            }.send()
        } else {
            super.subscribe(connection, afterSeq: afterSeq)
        }
    }

    private func begin(path: String, prompt: String, images: [[String: String]]) {
        var params: [String: Any] = [
            "cwd": path, "modelProvider": "openai",
            "approvalPolicy": permissionMode == "bypassPermissions" ? "never" : "on-request",
            "sandbox": permissionMode == "plan"
                ? "read-only" : permissionMode == "bypassPermissions" ? "danger-full-access" : "workspace-write",
        ]
        if let threadId { params["threadId"] = threadId }
        if threadId == nil, let projectId { params["projectId"] = projectId }
        if let model { params["model"] = model }
        codex.request(threadId == nil ? "thread/start" : "thread/resume", params: params, replyOn: deliveryQueue) {
            [weak self] result in
            if let self, !self.hasExited {
                switch result {
                case .failure(let error): self.fail(error.localizedDescription)
                case .success(let result):
                    if let thread = result["thread"] as? [String: Any], let id = thread["id"] as? String,
                        result["modelProvider"] as? String == "openai", let hostModel = result["model"] as? String
                    {
                        let selectedModel = self.reviewTarget == nil ? self.model ?? hostModel : hostModel
                        self.threadId = id
                        CodexSessionStore.shared.save(sessionId: self.sessionId, threadId: id, path: path)
                        self.emit(["type": "session", "provider": "codex", "threadId": id])
                        if self.shellCommand == nil {
                            self.emit(["event": ["type": "system", "subtype": "init", "model": selectedModel]])
                        }
                        if self.cancelled {
                            self.finish(exitCode: 0)
                        } else {
                            self.verifySubscription(path: path) { rejection in
                                if let rejection {
                                    self.fail(rejection)
                                } else if !self.hasExited, !self.cancelled {
                                    self.startTurn(
                                        id: id, model: selectedModel,
                                        effort: self.effort ?? result["reasoningEffort"] as? String,
                                        prompt: prompt, images: images)
                                }
                            }
                        }
                    } else {
                        self.fail("Codex did not return a subscription-backed thread.")
                    }
                }
            }
        }
    }

    private func verifySubscription(path: String, completion: @escaping (String?) -> Void) {
        let group = DispatchGroup()
        var responses: [String: [String: Any]] = [:]
        var failure: String?
        for method in ["account/read", "config/read"] + (shellCommand == nil ? ["account/rateLimits/read"] : []) {
            group.enter()
            codex.request(
                method, params: method == "config/read" ? ["cwd": path, "includeLayers": false] : [:],
                replyOn: deliveryQueue
            ) { result in
                switch result {
                case .success(let value): responses[method] = value
                case .failure(let error): failure = error.localizedDescription
                }
                group.leave()
            }
        }
        group.notify(queue: deliveryQueue) {
            completion(
                failure
                    ?? CodexSubscriptionPolicy.rejection(
                        account: responses["account/read"] ?? [:], config: responses["config/read"] ?? [:],
                        limits: responses["account/rateLimits/read"] ?? [:],
                        requireCapacity: self.shellCommand == nil))
        }
    }

    private func startTurn(id: String, model: String, effort: String?, prompt: String, images: [[String: String]]) {
        var input: [[String: Any]] = [["type": "text", "text": prompt]]
        for (kind, references) in [("skill", skills), ("mention", mentions)] {
            for reference in references {
                if let name = reference["name"], let path = reference["path"], !name.isEmpty && !path.isEmpty {
                    input.append(["type": kind, "name": name, "path": path])
                }
            }
        }
        input.append(
            contentsOf: images.compactMap { image in
                if let data = image["data"], let mediaType = image["mediaType"] {
                    return ["type": "image", "url": "data:\(mediaType);base64,\(data)"]
                }
                return nil
            })
        var turn: [String: Any] = [
            "threadId": id, "input": input,
            "collaborationMode": [
                "mode": permissionMode == "plan" ? "plan" : "default",
                "settings": [
                    "model": model, "reasoning_effort": effort as Any? ?? NSNull(), "developer_instructions": NSNull(),
                ],
            ],
        ]
        if let effort { turn["effort"] = effort }
        if let reviewTarget { turn = ["threadId": id, "target": reviewTarget, "delivery": "inline"] }
        if let shellCommand { turn = ["threadId": id, "command": shellCommand, "timeoutMs": 3_600_000] }
        codex.request(
            shellCommand != nil ? "thread/shellCommand" : reviewTarget == nil ? "turn/start" : "review/start",
            params: turn, replyOn: deliveryQueue, noTimeout: true
        ) {
            [weak self] result in
            if let self, !self.hasExited {
                switch result {
                case .failure(let error):
                    if self.turnId == nil { self.fail(error.localizedDescription) }
                case .success(let result):
                    if self.shellCommand != nil {
                        if self.cancelled { self.requestInterruptIfNeeded() }
                    } else if self.reviewTarget != nil, result["reviewThreadId"] as? String != self.threadId {
                        self.fail("Codex returned an unexpected review thread.")
                    } else if let turn = result["turn"] as? [String: Any], let id = turn["id"] as? String {
                        self.turnId = id
                        if self.cancelled { self.requestInterruptIfNeeded() }
                    } else {
                        self.fail("Codex did not start the requested turn.")
                    }
                }
            }
        }
    }

    override func abort() {
        cancelled = true
        requestInterruptIfNeeded()
    }

    private func requestInterruptIfNeeded() {
        if interruptRequested { return }
        if let threadId, let turnId, !hasExited {
            interruptRequested = true
            codex.request("turn/interrupt", params: ["threadId": threadId, "turnId": turnId], replyOn: deliveryQueue) {
                [weak self] result in
                if case .failure(let error) = result { self?.fail(error.localizedDescription) }
            }
            deliveryQueue.asyncAfter(deadline: .now() + 10) { [weak self] in
                if let self, !self.hasExited {
                    self.fail("Codex did not confirm interruption. Check the host before starting another turn.")
                }
            }
        }
    }

    override func finish(exitCode: Int32) {
        if journalFailed && !reportingStorageFailure { return }
        if let threadId { codex.settleGenerationStarts(threadId: threadId) }
        heartbeat?.cancel()
        heartbeat = nil
        codex.removeObserver(id: sessionId)
        for requestId in requests.keys {
            PushDelivery.shared.cancelNotification(eventId: "attention:\(sessionId):\(requestId)")
        }
        requests.removeAll()
        super.finish(exitCode: exitCode)
    }

    func steer(
        prompt: String, requestId: String? = nil, completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let requestId = requestId?.lowercased()
        deliveryQueue.async {
            let hash = Data(SHA256.hash(data: Data(prompt.utf8))).map { String(format: "%02x", $0) }.joined()
            if let requestId {
                if let existingHash = self.steerHashes[requestId], existingHash != hash {
                    completion(
                        .failure(
                            NSError(
                                domain: "Codex", code: 409,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "The steering request ID was already used with different content."
                                ])))
                    return
                }
                if let result = self.steerResults[requestId] {
                    completion(result)
                    return
                }
                if self.steerHashes[requestId] != nil {
                    self.steerWaiters[requestId, default: []].append(completion)
                    return
                }
                if let stored = self.steerReceipts.value(sessionId: self.sessionId, requestId: requestId) {
                    if stored["status"] == "unavailable" {
                        completion(
                            .failure(
                                NSError(
                                    domain: "Codex", code: 503,
                                    userInfo: [NSLocalizedDescriptionKey: "Steering durability is unavailable."])))
                    } else if stored["hash"] != hash {
                        completion(
                            .failure(
                                NSError(
                                    domain: "Codex", code: 409,
                                    userInfo: [
                                        NSLocalizedDescriptionKey:
                                            "The steering request ID was already used with different content."
                                    ])))
                    } else if stored["status"] == "accepted" {
                        completion(.success([:]))
                    } else {
                        completion(
                            .failure(
                                NSError(
                                    domain: "Codex", code: 409,
                                    userInfo: [
                                        NSLocalizedDescriptionKey:
                                            "The previous steering request has an unknown outcome. Refresh the task before retrying."
                                    ])))
                    }
                    return
                }
                self.steerHashes[requestId] = hash
                self.steerWaiters[requestId] = [completion]
                self.dispatchSteer(prompt: prompt, requestId: requestId)
            } else {
                self.dispatchSteer(prompt: prompt, completion: completion)
            }
        }
    }

    private func dispatchSteer(
        prompt: String, requestId: String? = nil, completion: ((Result<[String: Any], Error>) -> Void)? = nil
    ) {
        var claimed = false
        let finish: (Result<[String: Any], Error>) -> Void = { [weak self] result in
            if let requestId, let self {
                var settledResult = result
                if case .success = result {
                    if !self.steerReceipts.save(
                        sessionId: self.sessionId, requestId: requestId,
                        hash: self.steerHashes[requestId] ?? "", status: "accepted")
                    {
                        settledResult = .failure(
                            NSError(
                                domain: "Codex", code: 503,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "Steering result could not be persisted. Retry status from the task before sending again."
                                ]))
                    }
                }
                if claimed {
                    switch settledResult {
                    case .success: self.steerResults[requestId] = settledResult
                    case .failure:
                        self.steerResults[requestId] = .failure(
                            NSError(
                                domain: "Codex", code: 409,
                                userInfo: [
                                    NSLocalizedDescriptionKey:
                                        "The previous steering request has an unknown outcome. Refresh the task before retrying."
                                ]))
                    }
                } else {
                    self.steerHashes.removeValue(forKey: requestId)
                }
                let waiters = self.steerWaiters.removeValue(forKey: requestId) ?? []
                waiters.forEach { $0(settledResult) }
            } else {
                completion?(result)
            }
        }
        if shellCommand == nil, let threadId, let turnId, let path = workingPath {
            verifySubscription(path: path) { [weak self] rejection in
                if let rejection {
                    finish(
                        .failure(NSError(domain: "Codex", code: 402, userInfo: [NSLocalizedDescriptionKey: rejection])))
                } else if let self, !self.cancelled, !self.hasExited, self.turnId == turnId {
                    if let requestId {
                        claimed = self.steerReceipts.save(
                            sessionId: self.sessionId, requestId: requestId, hash: self.steerHashes[requestId] ?? "",
                            status: "pending")
                        if !claimed {
                            finish(
                                .failure(
                                    NSError(
                                        domain: "Codex", code: 503,
                                        userInfo: [
                                            NSLocalizedDescriptionKey:
                                                "Steering durability is unavailable. Retry after the host storage is writable."
                                        ])))
                            return
                        }
                    }
                    self.codex.request(
                        "turn/steer",
                        params: [
                            "threadId": threadId, "expectedTurnId": turnId,
                            "input": [["type": "text", "text": prompt]],
                        ],
                        replyOn: self.deliveryQueue, completion: finish)
                } else {
                    finish(
                        .failure(
                            NSError(
                                domain: "Codex", code: 409,
                                userInfo: [NSLocalizedDescriptionKey: "This task has no agent turn to steer."])))
                }
            }
        } else {
            finish(
                .failure(
                    NSError(
                        domain: "Codex", code: 409,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "This task has no agent turn to steer. Direct commands can be stopped and run again."
                        ])))
        }
    }

    func respond(requestId: String, result: [String: Any]) -> Bool {
        if let threadId, codex.respond(requestId: requestId, threadId: threadId, result: result) {
            requests.removeValue(forKey: requestId)
            PushDelivery.shared.cancelNotification(eventId: "attention:\(sessionId):\(requestId)")
            emit(["type": "request_resolved", "requestId": requestId])
            return true
        }
        return false
    }

    func requestList() -> [[String: Any]] {
        threadId.map { codex.pendingRequests(threadId: $0) } ?? []
    }

    private func fail(_ message: String) {
        if !hasExited {
            emit(["type": "error", "message": message])
            finish(exitCode: 1)
        }
    }

    private func receive(method: String, params: [String: Any]) {
        if method == "account/updated", !hasExited, let path = workingPath {
            verifySubscription(path: path) { [weak self] rejection in
                if let self, let rejection, !self.hasExited {
                    self.abort()
                    self.fail(rejection)
                }
            }
            return
        }
        if params["threadId"] as? String == threadId, !hasExited, !journalFailed {
            if method == "turn/started", let turn = params["turn"] as? [String: Any] {
                turnId = turn["id"] as? String
                if cancelled { requestInterruptIfNeeded() }
            }
            if method == "serverRequest/resolved", let id = params["requestId"] {
                for (key, request) in requests
                where (try? JSONSerialization.data(withJSONObject: [request.id]))
                    == (try? JSONSerialization.data(withJSONObject: [id]))
                {
                    requests.removeValue(forKey: key)
                    PushDelivery.shared.cancelNotification(eventId: "attention:\(sessionId):\(key)")
                    emit(["type": "request_resolved", "requestId": key])
                }
            }
            if ["thread/closed", "thread/archived", "thread/deleted"].contains(method) {
                fail("The task was closed on the host. Refresh its history before continuing.")
                return
            }
            var events = CodexEvent.envelopes(method: method, params: params)
            let item = params["item"] as? [String: Any]
            let itemType = item?["type"] as? String ?? ""
            if reviewTarget != nil {
                if method == "item/agentMessage/delta", let delta = params["delta"] as? String {
                    reviewHash.update(data: Data(delta.utf8))
                }
                if method == "item/completed", ["agentMessage", "exitedReviewMode"].contains(itemType) {
                    let digest = Data(
                        SHA256.hash(
                            data: Data((item?[itemType == "agentMessage" ? "text" : "review"] as? String ?? "").utf8)))
                    if reviewMessages.contains(digest)
                        || (itemType == "exitedReviewMode" && Data(reviewHash.finalize()) == digest)
                    {
                        events.removeAll { $0["event"] != nil }
                    }
                    if reviewMessages.count < 256 { reviewMessages.insert(digest) }
                }
            }
            if events.isEmpty, !CodexEvent.normalizedMethods.contains(method),
                !["enteredReviewMode", "exitedReviewMode"].contains(itemType)
            {
                emit(["codex": ["method": method, "params": params]])
            }
            for event in events { emit(event) }
            if method == "turn/completed" {
                finish(exitCode: (params["turn"] as? [String: Any])?["status"] as? String == "failed" ? 1 : 0)
            }
        }
    }
}
