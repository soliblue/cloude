import CryptoKit
import Foundation

final class CodexTerminal: @unchecked Sendable {
    static let shared = CodexTerminal()
    private let queue = DispatchQueue(label: "soli.Cloude.codex.terminals")
    private let inputQueue = DispatchQueue(label: "soli.Cloude.codex.terminal-input")
    private let client: CodexClient
    private let maxOutputBytes: Int
    private var terminals: [String: CodexTerminalEntry] = [:]
    private var starts: [String: CodexTerminalStart] = [:]
    private var pendingStarts = 0
    private var generation = 0
    private var observing = false
    private let retention: TimeInterval = 600
    var hasActiveWork: Bool { queue.sync { pendingStarts > 0 || terminals.values.contains { !$0.ended } } }

    init(client: CodexClient = .shared, maxOutputBytes: Int = 1_048_576) {
        self.client = client
        self.maxOutputBytes = maxOutputBytes
    }

    func start(sessionId: String, requestId: String, cwd: String, rows: Int, cols: Int) -> Result<[String: Any], Error>
    {
        guard let admission = DaemonLifecycle.shared.begin() else {
            return .failure(Self.error("daemon_updating", code: 503))
        }
        var transferred = false
        defer { if !transferred { DaemonLifecycle.shared.end(admission) } }
        let key = sessionId.lowercased() + ":" + requestId.lowercased()
        let operation = CodexTerminalRequest<[String: Any]>()
        let reservation: (CodexTerminalRequest<[String: Any]>, Bool, Int) = queue.sync {
            prune()
            if let existing = starts[key] {
                if existing.cwd == cwd, existing.rows == rows, existing.cols == cols {
                    if let id = existing.processId, let entry = terminals[id] {
                        operation.finish(.success(snapshot(entry)))
                        return (operation, false, generation)
                    }
                    return (existing.operation, false, generation)
                }
                operation.finish(.failure(Self.error("request_id_reused", code: 409)))
                return (operation, false, generation)
            }
            if terminals.values.filter({ !$0.ended }).count + pendingStarts >= 4 {
                operation.finish(.failure(Self.error("terminal_limit_reached", code: 409)))
                return (operation, false, generation)
            }
            pendingStarts += 1
            starts[key] = CodexTerminalStart(cwd: cwd, rows: rows, cols: cols, operation: operation)
            observeIfNeeded()
            return (operation, true, generation)
        }
        if reservation.1 {
            var directory: ObjCBool = false
            var rejection: Error?
            if !FileManager.default.fileExists(atPath: cwd, isDirectory: &directory) || !directory.boolValue {
                rejection = Self.error("Choose an existing working directory.", code: 400)
            } else {
                switch request("account/read", params: ["refreshToken": false]) {
                case .failure(let error): rejection = error
                case .success(let account):
                    switch request("config/read", params: ["cwd": cwd, "includeLayers": false]) {
                    case .failure(let error): rejection = error
                    case .success(let config):
                        if let message = CodexSubscriptionPolicy.rejection(
                            account: account, config: config, limits: [:], requireCapacity: false)
                        {
                            rejection = Self.error(message, code: 403)
                        }
                    }
                }
            }
            queue.sync {
                pendingStarts -= 1
                if generation != reservation.2 {
                    rejection = Self.error("The host connection changed while opening this terminal.", code: 502)
                }
                if let rejection {
                    starts.removeValue(forKey: key)
                    operation.finish(.failure(rejection))
                } else {
                    let processId = UUID().uuidString.lowercased()
                    terminals[processId] = CodexTerminalEntry(
                        admission: admission, sessionId: sessionId.lowercased(), processId: processId, startKey: key,
                        cwd: cwd,
                        createdAt: Date(), rows: rows, cols: cols)
                    transferred = true
                    starts[key]?.processId = processId
                    emit(
                        processId: processId,
                        event: snapshot(terminals[processId]!).merging(["type": "terminal_state"]) { _, new in new })
                    client.request(
                        "command/exec",
                        params: [
                            "command": ["/bin/sh", "-i"], "cwd": cwd, "processId": processId,
                            "tty": true, "streamStdin": true, "streamStdoutStderr": true, "disableTimeout": true,
                            "disableOutputCap": true, "size": ["rows": rows, "cols": cols],
                            "env": ["TERM": "xterm-256color", "COLORTERM": "truecolor"],
                            "sandboxPolicy": ["type": "dangerFullAccess"],
                        ], replyOn: queue, noTimeout: true
                    ) { [weak self] result in self?.finish(processId: processId, result: result) }
                    operation.finish(.success(snapshot(terminals[processId]!)))
                }
            }
        }
        return reservation.0.wait()
    }

    func list(sessionId: String) -> [[String: Any]] {
        queue.sync {
            prune()
            return terminals.values.filter { $0.sessionId == sessionId.lowercased() }.map(snapshot).sorted {
                ($0["terminalId"] as? String ?? "") < ($1["terminalId"] as? String ?? "")
            }
        }
    }

    func stream(sessionId: String, terminalId: String, cursor: Int) -> [[String: Any]]? {
        queue.sync {
            prune()
            if let entry = terminals[terminalId], entry.sessionId == sessionId.lowercased() {
                return entry.events.filter { ($0["seq"] as? Int ?? 0) > cursor }
            }
            return nil
        }
    }

    func subscribe(
        sessionId: String, terminalId: String, cursor: Int, subscriberId: String,
        receive: @escaping ([String: Any]?, Bool) -> Void
    ) {
        queue.async {
            self.prune()
            if let entry = self.terminals[terminalId], entry.sessionId == sessionId.lowercased() {
                let firstSeq = entry.events.first?["seq"] as? Int ?? entry.nextSeq
                if cursor < firstSeq - 1 {
                    receive(["type": "terminal_gap", "firstSeq": firstSeq, "requestedAfterSeq": cursor], false)
                }
                for event in entry.events where (event["seq"] as? Int ?? 0) > cursor { receive(event, false) }
                receive(self.snapshot(entry).merging(["type": "terminal_ready"]) { _, new in new }, entry.ended)
                if !entry.ended { self.terminals[terminalId]?.subscribers[subscriberId] = receive }
            } else {
                receive(["type": "terminal_error", "error": "terminal_not_found"], true)
            }
        }
    }

    func unsubscribe(terminalId: String, subscriberId: String) {
        queue.async { self.terminals[terminalId]?.subscribers.removeValue(forKey: subscriberId) }
    }

    func input(
        sessionId: String, terminalId: String, writerId: String, sequence: Int, data: Data, close: Bool
    ) -> Result<Bool, Error> {
        let operation = CodexTerminalRequest<Bool>()
        let fingerprint = Data(SHA256.hash(data: data + Data([close ? 1 : 0])))
        let selected: (CodexTerminalRequest<Bool>, Bool) = queue.sync {
            if let entry = terminals[terminalId], entry.sessionId == sessionId.lowercased() {
                if let previous = entry.input[writerId.lowercased()], sequence == previous.sequence {
                    if previous.fingerprint == fingerprint { return (previous.operation, true) }
                    operation.finish(.failure(Self.error("sequence_reused", code: 409)))
                } else if entry.ended {
                    operation.finish(.failure(Self.error("terminal_not_running", code: 409)))
                } else if sequence != (entry.input[writerId.lowercased()].map { $0.sequence + 1 } ?? 0) {
                    operation.finish(.failure(Self.error("sequence_out_of_order", code: 409)))
                } else if data.count > 64 * 1024
                    || (entry.input[writerId.lowercased()] == nil && entry.input.count >= 64)
                    || entry.pendingInputs >= 64
                {
                    operation.finish(.failure(Self.error("terminal_input_limit", code: 409)))
                } else {
                    terminals[terminalId]?.input[writerId.lowercased()] = CodexTerminalInput(
                        sequence: sequence, fingerprint: fingerprint, operation: operation)
                    terminals[terminalId]?.pendingInputs += 1
                    inputQueue.async {
                        let result = self.request(
                            "command/exec/write",
                            params: [
                                "processId": terminalId, "deltaBase64": data.base64EncodedString(), "closeStdin": close,
                            ])
                        self.queue.sync { self.terminals[terminalId]?.pendingInputs -= 1 }
                        operation.finish(result.map { _ in false })
                    }
                }
            } else {
                operation.finish(.failure(Self.error("terminal_not_found", code: 404)))
            }
            return (operation, false)
        }
        return selected.0.wait().map { selected.1 || $0 }
    }

    func resize(sessionId: String, terminalId: String, rows: Int, cols: Int) -> Result<[String: Any], Error> {
        if queue.sync(execute: {
            terminals[terminalId].map { $0.sessionId == sessionId.lowercased() && !$0.ended } ?? false
        }) {
            return request(
                "command/exec/resize", params: ["processId": terminalId, "size": ["rows": rows, "cols": cols]]
            ).map { _ in
                queue.sync {
                    if terminals[terminalId]?.ended == false {
                        terminals[terminalId]?.rows = rows
                        terminals[terminalId]?.cols = cols
                        emit(
                            processId: terminalId,
                            event: snapshot(terminals[terminalId]!).merging(["type": "terminal_state"]) { _, new in new
                            })
                    }
                    return terminals[terminalId].map(snapshot) ?? [:]
                }
            }
        }
        return .failure(Self.error("terminal_not_running", code: 409))
    }

    func terminate(sessionId: String, terminalId: String) -> Result<[String: Any], Error> {
        if queue.sync(execute: {
            terminals[terminalId].map { $0.sessionId == sessionId.lowercased() && !$0.ended } ?? false
        }) {
            return request("command/exec/terminate", params: ["processId": terminalId])
        }
        return .failure(Self.error("terminal_not_running", code: 409))
    }

    private func request(_ method: String, params: [String: Any]) -> Result<[String: Any], Error> {
        let operation = CodexTerminalRequest<[String: Any]>()
        client.request(method, params: params) { operation.finish($0) }
        return operation.wait().mapError { Self.error($0.localizedDescription, code: 502) }
    }

    private func observeIfNeeded() {
        if !observing {
            observing = true
            client.observe(
                id: "codex-terminals", on: queue, message: { [weak self] message in self?.receive(message) },
                disconnected: { [weak self] error in self?.disconnect(error) })
        }
    }

    private func receive(_ message: [String: Any]) {
        if message["method"] as? String == "command/exec/outputDelta",
            let params = message["params"] as? [String: Any], let processId = params["processId"] as? String,
            terminals[processId]?.ended == false, let delta = params["deltaBase64"] as? String,
            let data = Data(base64Encoded: delta)
        {
            for offset in stride(from: 0, to: data.count, by: 32_768) {
                emit(
                    processId: processId,
                    event: [
                        "type": "terminal_output", "processId": processId,
                        "stream": params["stream"] as? String ?? "stdout",
                        "deltaBase64": data.subdata(in: offset..<min(offset + 32_768, data.count))
                            .base64EncodedString(), "capReached": params["capReached"] as? Bool ?? false,
                    ])
            }
        }
    }

    private func emit(processId: String, event: [String: Any]) {
        if var entry = terminals[processId] {
            var value = event
            value["seq"] = entry.nextSeq
            if value["type"] as? String == "terminal_state" { value["lastSeq"] = entry.nextSeq }
            entry.nextSeq += 1
            entry.events.append(value)
            entry.outputBytes += (try? JSONSerialization.data(withJSONObject: value).count) ?? 0
            while entry.outputBytes > maxOutputBytes && entry.events.count > 1 {
                entry.outputBytes -=
                    (try? JSONSerialization.data(withJSONObject: entry.events.removeFirst()).count) ?? 0
            }
            terminals[processId] = entry
            for receive in entry.subscribers.values { receive(value, false) }
        }
    }

    private func finish(processId: String, result: Result<[String: Any], Error>) {
        if terminals[processId]?.ended == false {
            DaemonLifecycle.shared.end(terminals[processId]!.admission)
            terminals[processId]?.ended = true
            terminals[processId]?.endedAt = Date()
            switch result {
            case .success(let value): terminals[processId]?.exitCode = value["exitCode"] as? Int
            case .failure(let error): terminals[processId]?.error = error.localizedDescription
            }
            emit(
                processId: processId,
                event: snapshot(terminals[processId]!).merging(["type": "terminal_state"]) { _, new in new })
            for receive in terminals[processId]!.subscribers.values { receive(nil, true) }
            terminals[processId]?.subscribers.removeAll()
        }
    }

    private func disconnect(_ error: Error) {
        generation += 1
        for processId in terminals.keys { finish(processId: processId, result: .failure(error)) }
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-retention)
        for entry in terminals.values where entry.ended && (entry.endedAt ?? .distantFuture) <= cutoff {
            starts.removeValue(forKey: entry.startKey)
            terminals.removeValue(forKey: entry.processId)
        }
    }

    private func snapshot(_ entry: CodexTerminalEntry) -> [String: Any] {
        [
            "terminalId": entry.processId, "processId": entry.processId, "sessionId": entry.sessionId,
            "path": entry.cwd,
            "status": entry.ended ? (entry.error == nil ? "exited" : "failed") : "running",
            "rows": entry.rows, "cols": entry.cols, "createdAt": entry.createdAt.timeIntervalSince1970 * 1000,
            "exitCode": entry.exitCode.map { $0 as Any } ?? NSNull(),
            "error": entry.error.map { $0 as Any } ?? NSNull(), "eventCount": entry.events.count,
            "lastSeq": entry.nextSeq - 1,
        ]
    }

    private static func error(_ message: String, code: Int) -> NSError {
        NSError(domain: "CodexTerminal", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
