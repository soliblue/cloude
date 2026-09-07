import Foundation

final class CodexCompactionService {
    static let shared = CodexCompactionService()
    private let queue = DispatchQueue(label: "app.afto.codex.compaction")
    private var states: [String: CodexCompactionState] = [:]
    private let transport: (String, [String: Any], @escaping (Result<[String: Any], Error>) -> Void) -> Void
    private let reserve: (String) -> Bool
    private let release: (String) -> Void

    init(
        transport: @escaping (String, [String: Any], @escaping (Result<[String: Any], Error>) -> Void) -> Void = {
            CodexClient.shared.request($0, params: $1, completion: $2)
        },
        reserve: @escaping (String) -> Bool = { RunnerManager.shared.reserveCompaction(threadId: $0) },
        release: @escaping (String) -> Void = { RunnerManager.shared.releaseCompaction(threadId: $0) },
        observing: Bool = true
    ) {
        self.transport = transport
        self.reserve = reserve
        self.release = release
        if observing {
            CodexClient.shared.observe(
                id: "codex-compaction", on: queue,
                message: { [weak self] value in
                    self?.notification(value)
                }, disconnected: { [weak self] _ in self?.disconnected() })
        }
    }

    func snapshot(threadId: String) -> [String: Any] {
        queue.sync { states[threadId]?.json ?? ["status": "idle", "threadId": threadId] }
    }

    func start(threadId: String) -> (Int, [String: Any]) {
        queue.sync {
            if let state = states[threadId], state.status == "pending" { return (202, state.json) }
            if states.count >= 512 {
                if let finished = states.first(where: { $0.value.status != "pending" }) {
                    states.removeValue(forKey: finished.key)
                } else {
                    return (503, ["error": "Too many compactions are pending. Wait for one to finish."])
                }
            }
            if reserve(threadId) {
                let state = CodexCompactionState(threadId: threadId)
                states[threadId] = state
                Task { await run(threadId: threadId, operationId: state.operationId) }
                return (202, state.json)
            }
            return (409, ["error": "Wait for the active turn to finish before compacting context."])
        }
    }

    private func call(_ method: String, _ params: [String: Any] = [:]) async -> [String: Any]? {
        let result: Result<[String: Any], Error> = await withCheckedContinuation { continuation in
            transport(method, params) { continuation.resume(returning: $0) }
        }
        if case .success(let value) = result { return value }
        return nil
    }

    private func run(threadId: String, operationId: UUID) async {
        if let value = await call("thread/read", ["threadId": threadId, "includeTurns": false]),
            let thread = value["thread"] as? [String: Any], let cwd = thread["cwd"] as? String,
            !cwd.isEmpty, thread["modelProvider"] as? String == "openai"
        {
            if (thread["status"] as? [String: Any])?["type"] as? String == "active" {
                fail(threadId, operationId, "Wait for the active turn to finish before compacting context.")
                return
            }
            async let account = call("account/read", ["refreshToken": false])
            async let config = call("config/read", ["cwd": cwd, "includeLayers": false])
            async let limits = call("account/rateLimits/read")
            if let account = await account, let config = await config, let limits = await limits {
                if let error = CodexSubscriptionPolicy.rejection(account: account, config: config, limits: limits) {
                    fail(threadId, operationId, error)
                    return
                }
                if !pending(threadId, operationId) { return }
                if let resumed = await call(
                    "thread/resume", ["threadId": threadId, "cwd": cwd, "modelProvider": "openai"]),
                    resumed["modelProvider"] as? String == "openai",
                    ((resumed["thread"] as? [String: Any])?["status"] as? [String: Any])?["type"] as? String != "active"
                {
                    let started = queue.sync {
                        if states[threadId]?.operationId == operationId, states[threadId]?.status == "pending" {
                            states[threadId]?.started = true
                            return true
                        }
                        return false
                    }
                    if started, await call("thread/compact/start", ["threadId": threadId]) == nil {
                        fail(
                            threadId, operationId,
                            "Codex could not start compaction. Check the host connection and retry.")
                    }
                    return
                }
            }
        }
        fail(
            threadId, operationId,
            "Compaction requires an idle task with a connected ChatGPT subscription and available capacity.")
    }

    private func pending(_ threadId: String, _ operationId: UUID) -> Bool {
        queue.sync { states[threadId]?.operationId == operationId && states[threadId]?.status == "pending" }
    }

    private func fail(_ threadId: String, _ operationId: UUID, _ error: String) {
        queue.sync {
            if states[threadId]?.operationId == operationId, states[threadId]?.status == "pending" {
                states[threadId]?.status = "failed"
                states[threadId]?.error = error
                states[threadId]?.started = false
                release(threadId)
            }
        }
    }

    func notification(_ message: [String: Any]) {
        queue.async {
            if let method = message["method"] as? String, let params = message["params"] as? [String: Any],
                let threadId = params["threadId"] as? String, var state = self.states[threadId]
            {
                if method == "thread/tokenUsage/updated", ["pending", "completed"].contains(state.status),
                    state.started || (state.turnId != nil && state.turnId == params["turnId"] as? String),
                    let usage = params["tokenUsage"] as? [String: Any]
                {
                    if let tokens = (usage["last"] as? [String: Any])?["totalTokens"] as? Int, tokens >= 0 {
                        state.contextTokens = tokens
                    }
                    if let window = usage["modelContextWindow"] as? Int, window > 0 { state.contextWindow = window }
                }
                if state.started, state.status == "pending" {
                    if method == "turn/started" { state.turnId = (params["turn"] as? [String: Any])?["id"] as? String }
                    if method == "item/started",
                        (params["item"] as? [String: Any])?["type"] as? String == "contextCompaction"
                    {
                        state.turnId = params["turnId"] as? String
                    }
                    if method == "thread/compacted" { state.status = "completed" }
                    if method == "turn/completed", let turn = params["turn"] as? [String: Any],
                        let turnId = state.turnId, turnId == turn["id"] as? String
                    {
                        state.status = turn["status"] as? String == "completed" ? "completed" : "failed"
                        if state.status == "failed" {
                            state.error = "Context compaction stopped before completing. Retry when the task is idle."
                        }
                    }
                    if method == "error", params["willRetry"] as? Bool != true,
                        params["turnId"] == nil || state.turnId == nil || params["turnId"] as? String == state.turnId
                    {
                        state.status = "failed"
                        state.error = "Codex could not compact this task. Check its subscription capacity and retry."
                    }
                    if state.status != "pending" {
                        state.started = false
                        self.release(threadId)
                    }
                }
                self.states[threadId] = state
            }
        }
    }

    func disconnected() {
        queue.async {
            for threadId in self.states.keys where self.states[threadId]?.status == "pending" {
                self.states[threadId]?.status = "failed"
                self.states[threadId]?.started = false
                self.states[threadId]?.error =
                    "Codex disconnected during compaction. Refresh task history before retrying."
                self.release(threadId)
            }
        }
    }
}
