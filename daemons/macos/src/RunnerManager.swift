import Foundation
import Network

final class RunnerManager {
    static let shared = RunnerManager()

    private let queue = DispatchQueue(label: "soli.Cloude.runner")
    private var runners: [String: Runner] = [:]
    private var compactingThreads: [String: UUID] = [:]
    private var helperAttention: [String: (sessionId: String, threadId: String)] = [:]

    init() {
        CodexClient.shared.observe(
            id: "runner-manager", on: queue,
            message: { [weak self] message in self?.handleCodexMessage(message) },
            disconnected: { [weak self] _ in self?.clearHelperAttention() })
    }

    func reserveCompaction(threadId: String) -> Bool {
        queue.sync {
            if !compactingThreads.keys.contains(threadId),
                !runners.values.contains(where: { ($0 as? CodexRunner)?.threadId == threadId && !$0.hasExited })
            {
                if let admission = DaemonLifecycle.shared.begin() {
                    compactingThreads[threadId] = admission
                    return true
                }
            }
            return false
        }
    }

    func releaseCompaction(threadId: String) {
        queue.async {
            if let admission = self.compactingThreads.removeValue(forKey: threadId) {
                DaemonLifecycle.shared.end(admission)
            }
        }
    }

    func isCompacting(threadId: String) -> Bool {
        queue.sync { compactingThreads[threadId] != nil }
    }

    func isRunning(sessionId: String) -> Bool {
        queue.sync {
            runners[sessionId.lowercased()].map { !$0.hasExited } == true
                || CodexSessionStore.shared.threadId(for: sessionId).map { compactingThreads.keys.contains($0) } == true
        }
    }

    func isIdleForUpdate() -> Bool {
        queue.sync {
            runners.values.allSatisfy { $0.hasExited }
                && compactingThreads.isEmpty
                && helperAttention.isEmpty
                && !CodexClient.shared.hasPendingWork
                && !CodexTerminal.shared.hasActiveWork
        }
    }

    func start(
        sessionId: String, path: String, prompt: String, images: [[String: String]],
        existsOnServer: Bool, model: String?, effort: String?, permissionMode: String?,
        provider: String?, threadId: String?,
        skills: [[String: String]] = [], mentions: [[String: String]] = [], projectId: String? = nil,
        reviewTarget: [String: Any]? = nil, shellCommand: String? = nil, connection: NWConnection
    ) {
        guard let admission = DaemonLifecycle.shared.begin() else {
            connection.send(
                content: Data(
                    "{\"type\":\"error\",\"message\":\"The daemon is restarting for an update. Reconnect and retry.\",\"seq\":1}\n{\"type\":\"exit\",\"code\":1,\"seq\":2}\n"
                        .utf8), isComplete: true, completion: .contentProcessed { _ in connection.cancel() })
            return
        }
        let sessionId = sessionId.lowercased()
        queue.async {
            var transferred = false
            defer { if !transferred { DaemonLifecycle.shared.end(admission) } }
            if let threadId = threadId ?? CodexSessionStore.shared.threadId(for: sessionId),
                self.compactingThreads.keys.contains(threadId)
                    || self.runners.values.contains(where: {
                        ($0 as? CodexRunner)?.threadId == threadId && !$0.hasExited
                    })
            {
                let message =
                    "{\"type\":\"error\",\"message\":\"Wait for the active turn or context compaction to finish before sending again.\",\"seq\":1}\n{\"type\":\"exit\",\"code\":1,\"seq\":2}\n"
                connection.send(
                    content: Data(message.utf8), isComplete: true,
                    completion: .contentProcessed { _ in connection.cancel() })
                return
            }
            NSLog(
                "[RunnerManager] start sessionId=\(sessionId) path=\(path) existsOnServer=\(existsOnServer) model=\(model ?? "nil") effort=\(effort ?? "nil") permissionMode=\(permissionMode ?? "nil") promptChars=\(prompt.count) images=\(images.count)"
            )
            if let previous = self.runners[sessionId], !previous.hasExited {
                let message =
                    "{\"type\":\"error\",\"message\":\"This task already has a running turn. Wait, steer it, or interrupt it before sending again.\",\"seq\":1}\n{\"type\":\"exit\",\"code\":1,\"seq\":2}\n"
                connection.send(
                    content: Data(message.utf8), isComplete: true,
                    completion: .contentProcessed { _ in connection.cancel() })
                return
            }
            let runner: Runner =
                provider == "codex"
                ? CodexRunner(
                    sessionId: sessionId, hasStartedBefore: existsOnServer, model: model, effort: effort,
                    permissionMode: permissionMode, threadId: threadId, skills: skills, mentions: mentions,
                    projectId: projectId, reviewTarget: reviewTarget, shellCommand: shellCommand, queue: self.queue
                )
                : Runner(
                    sessionId: sessionId, hasStartedBefore: existsOnServer, model: model, effort: effort,
                    permissionMode: permissionMode, queue: self.queue)
            runner.onFinish = { [weak self, weak runner] in
                DaemonLifecycle.shared.end(admission)
                self?.queue.async {
                    if let runner, self?.runners[sessionId] === runner {
                        if let threadId = (runner as? CodexRunner)?.threadId {
                            CodexClient.shared.unregisterOwner(threadId: threadId, sessionId: sessionId)
                        }
                        self?.clearHelperAttention(sessionId: sessionId)
                        self?.runners.removeValue(forKey: sessionId)
                    }
                }
            }
            transferred = true
            self.runners[sessionId] = runner
            if let threadId { CodexClient.shared.registerOwner(threadId: threadId, sessionId: sessionId) }
            runner.subscribe(connection)
            let resolvedPrompt =
                provider == "codex"
                ? prompt : ImageDropbox.prepare(cwd: path, prompt: prompt, images: images, sessionId: sessionId)
            runner.spawn(path: path, prompt: resolvedPrompt, images: images)
        }
    }

    func resumeIfExists(sessionId: String, afterSeq: Int, connection: NWConnection) -> Bool {
        queue.sync {
            if let runner = runners[sessionId.lowercased()] {
                runner.subscribe(connection, afterSeq: afterSeq)
                return true
            }
            return false
        }
    }

    func abort(sessionId: String) -> Bool {
        queue.sync {
            if let runner = self.runners[sessionId.lowercased()] {
                runner.abort()
                return true
            }
            return false
        }
    }

    func steer(
        sessionId: String, prompt: String, requestId: String? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) -> Bool {
        queue.sync {
            if let runner = runners[sessionId.lowercased()] as? CodexRunner {
                runner.steer(prompt: prompt, requestId: requestId, completion: completion)
                return true
            }
            if let requestId,
                let status = CodexSteerReceiptStore.shared.status(
                    sessionId: sessionId, requestId: requestId, prompt: prompt)
            {
                if status == "accepted" {
                    completion(.success([:]))
                } else {
                    completion(
                        .failure(
                            NSError(
                                domain: "Codex", code: 409,
                                userInfo: [
                                    NSLocalizedDescriptionKey: status == "mismatch"
                                        ? "The steering request ID was already used with different content."
                                        : "The previous steering request has an unknown outcome. Refresh the task before retrying."
                                ])))
                }
                return true
            }
            return false
        }
    }

    func respond(sessionId: String, requestId: String, result: [String: Any]) -> Bool {
        queue.sync {
            if let runner = runners[sessionId.lowercased()] as? CodexRunner {
                return runner.respond(requestId: requestId, result: result)
            }
            return CodexClient.shared.respond(
                requestId: requestId,
                threadId: CodexSessionStore.shared.threadId(for: sessionId) ?? sessionId, result: result)
        }
    }

    func requests(sessionId: String) -> [[String: Any]] {
        queue.sync {
            (runners[sessionId.lowercased()] as? CodexRunner)?.requestList()
                ?? CodexClient.shared.pendingRequests(
                    threadId: CodexSessionStore.shared.threadId(for: sessionId) ?? sessionId)
        }
    }

    func agentAttention(sessionId: String) -> [[String: Any]] {
        queue.sync {
            let threadId =
                (runners[sessionId.lowercased()] as? CodexRunner)?.threadId
                ?? CodexSessionStore.shared.threadId(for: sessionId) ?? sessionId
            return CodexClient.shared.attentionForThread(threadId)
        }
    }

    private func handleCodexMessage(_ message: [String: Any]) {
        refreshOwners()
        guard let method = message["method"] as? String,
            let params = message["params"] as? [String: Any], let threadId = params["threadId"] as? String
        else { return }
        let key =
            params["requestKey"] as? String
            ?? (params["requestId"].flatMap { CodexClient.shared.pendingKey(id: $0, threadId: threadId) })
        if method == "serverRequest/resolved", let key { clearHelperAttention(key: key) }
        if message["id"] != nil, let key, let owner = CodexClient.shared.ownerForThread(threadId),
            owner.threadId != threadId,
            let runner = runners[owner.sessionId], !runner.hasExited, helperAttention[key] == nil
        {
            helperAttention[key] = (owner.sessionId, threadId)
            runner.emit(["type": "agent_attention", "threadId": threadId, "requestId": key, "pending": true])
            PushDelivery.shared.enqueueNotification(
                sessionId: owner.sessionId, title: "A helper needs your attention",
                body: "Open the helper task to review its request and continue.", kind: "attention",
                eventId: "attention:\(owner.sessionId):\(key)")
        }
    }

    private func refreshOwners() {
        for (sessionId, runner) in runners {
            if let threadId = (runner as? CodexRunner)?.threadId {
                CodexClient.shared.registerOwner(threadId: threadId, sessionId: sessionId)
            }
        }
    }

    private func clearHelperAttention(key: String) {
        if let attention = helperAttention.removeValue(forKey: key), let runner = runners[attention.sessionId],
            !runner.hasExited
        {
            runner.emit(["type": "agent_attention", "threadId": attention.threadId, "requestId": key, "pending": false])
            PushDelivery.shared.cancelNotification(eventId: "attention:\(attention.sessionId):\(key)")
        }
    }

    private func clearHelperAttention(sessionId: String? = nil) {
        for key in Array(helperAttention.keys) where sessionId == nil || helperAttention[key]?.sessionId == sessionId {
            clearHelperAttention(key: key)
        }
    }
}
