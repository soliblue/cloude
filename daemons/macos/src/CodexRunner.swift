import Foundation
import Network

final class CodexRunner: ChatRunning {
    let sessionId: String
    private(set) var hasExited = false
    var onFinish: (() -> Void)?

    private let hasStartedBefore: Bool
    private let model: String?
    private let effort: String?
    private let permissionMode: String?
    private let queue: DispatchQueue
    private var process: Process?
    private var stdinPipe: Pipe?
    private var ring: [(seq: Int, data: Data)] = []
    private var subscribers: [NWConnection] = []
    private var seq = 0
    private var lineBuffer = Data()
    private var nextRequestId = 1
    private var pending: [Int: ([String: Any]) -> Void] = [:]
    private var activeThreadId: String?
    private var activeTurnId: String?
    private var agentTextByItem: [String: String] = [:]
    private var outputByItem: [String: String] = [:]
    private var contextTokens: Int?
    private var contextWindow: Int?
    private let maxRingSize = 1000

    init(
        sessionId: String, hasStartedBefore: Bool, model: String?, effort: String?,
        permissionMode: String?, queue: DispatchQueue
    ) {
        self.sessionId = sessionId
        self.hasStartedBefore = hasStartedBefore
        self.model = model
        self.effort = effort
        self.permissionMode = permissionMode
        self.queue = queue
    }

    func spawn(path: String, prompt: String, imagePaths: [String]) {
        let proc = Process()
        let stdout = Pipe()
        let stdin = Pipe()
        let stderr = Pipe()
        let executable = Self.codexExecutable()
        proc.executableURL = URL(fileURLWithPath: executable.path)
        proc.arguments = executable.leadingArguments + ["app-server", "--listen", "stdio://"]
        proc.currentDirectoryURL = URL(fileURLWithPath: path)
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr
        proc.environment = Self.spawnEnvironment()

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            self?.queue.async { self?.ingest(data) }
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            #if DEBUG
            let text = String(data: data, encoding: .utf8) ?? "<binary \(data.count)>"
            NSLog("[CodexRunner] stderr sessionId=\(self?.sessionId ?? "?"): \(text)")
            #endif
        }

        proc.terminationHandler = { p in
            self.queue.async { self.finish(exitCode: p.terminationStatus, terminatesProcess: false) }
        }

        if (try? proc.run()) != nil {
            process = proc
            stdinPipe = stdin
            initialize(path: path, prompt: prompt, imagePaths: imagePaths)
        } else {
            emit(["type": "error", "message": "spawn_failed: codex app-server"])
            finish(exitCode: -1)
        }
    }

    func subscribe(_ connection: NWConnection, afterSeq: Int = -1) {
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            switch state {
            case .failed, .cancelled:
                self?.queue.async { self?.removeSubscriber(connection) }
            default: break
            }
        }
        var batch = Data()
        for (s, data) in ring where s > afterSeq { batch.append(data) }
        if !batch.isEmpty {
            connection.send(content: batch, completion: .contentProcessed { _ in })
        }
        if hasExited {
            connection.cancel()
        } else {
            subscribers.append(connection)
        }
    }

    func abort() {
        if let turnId = activeTurnId, let threadId = activeThreadId {
            emit(["type": "aborted"])
            request(method: "turn/interrupt", params: ["threadId": threadId, "turnId": turnId]) { _ in }
        }
        queue.asyncAfter(deadline: .now() + 5) { [weak self] in
            if let self, !self.hasExited { self.finish(exitCode: 130) }
        }
    }

    private func initialize(path: String, prompt: String, imagePaths: [String]) {
        request(
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "remote_cc",
                    "title": "Remote CC",
                    "version": DaemonVersion.current,
                ],
                "capabilities": ["experimentalApi": true],
            ]
        ) { _ in }
        notify(method: "initialized", params: [:])
        if hasStartedBefore, let threadId = CodexThreadStore.shared.threadId(sessionId: sessionId) {
            resume(threadId: threadId, path: path, prompt: prompt, imagePaths: imagePaths)
        } else {
            startThread(path: path, prompt: prompt, imagePaths: imagePaths)
        }
    }

    private func startThread(path: String, prompt: String, imagePaths: [String]) {
        var params = baseThreadParams(path: path)
        params["serviceName"] = "remote_cc"
        request(method: "thread/start", params: params) { [weak self] result in
            self?.threadReady(result: result, path: path, prompt: prompt, imagePaths: imagePaths)
        }
    }

    private func resume(threadId: String, path: String, prompt: String, imagePaths: [String]) {
        var params = baseThreadParams(path: path)
        params["threadId"] = threadId
        params["excludeTurns"] = true
        request(method: "thread/resume", params: params) { [weak self] result in
            self?.threadReady(result: result, path: path, prompt: prompt, imagePaths: imagePaths)
        }
    }

    private func threadReady(
        result: [String: Any], path: String, prompt: String, imagePaths: [String]
    ) {
        if let thread = result["thread"] as? [String: Any],
            let threadId = thread["id"] as? String
        {
            activeThreadId = threadId
            CodexThreadStore.shared.set(threadId: threadId, sessionId: sessionId)
            emit(["event": ["type": "system", "subtype": "init", "session_id": threadId]])
            startTurn(threadId: threadId, path: path, prompt: prompt, imagePaths: imagePaths)
        } else {
            emit(["type": "error", "message": "codex_thread_missing"])
            finish(exitCode: -1)
        }
    }

    private func startTurn(threadId: String, path: String, prompt: String, imagePaths: [String]) {
        var params: [String: Any] = [
            "threadId": threadId,
            "input": input(prompt: prompt, imagePaths: imagePaths),
            "cwd": path,
        ]
        if let model { params["model"] = model }
        if let resolvedEffort { params["effort"] = resolvedEffort }
        request(method: "turn/start", params: params) { [weak self] result in
            if let turn = result["turn"] as? [String: Any], let turnId = turn["id"] as? String {
                self?.activeTurnId = turnId
            }
        }
    }

    private func input(prompt: String, imagePaths: [String]) -> [[String: Any]] {
        var items: [[String: Any]] = [["type": "text", "text": prompt, "text_elements": [] as [Any]]]
        for path in imagePaths {
            items.append(["type": "localImage", "path": path])
        }
        return items
    }

    private func baseThreadParams(path: String) -> [String: Any] {
        var params: [String: Any] = [
            "cwd": path,
            "approvalPolicy": approvalPolicy,
            "sandbox": sandboxMode,
            "experimentalRawEvents": false,
            "persistExtendedHistory": false,
        ]
        if let model { params["model"] = model }
        if let resolvedEffort { params["effort"] = resolvedEffort }
        return params
    }

    private var resolvedEffort: String? {
        if effort == "max" { return "xhigh" }
        return effort
    }

    private var approvalPolicy: String {
        permissionMode == "bypassPermissions" ? "never" : "on-request"
    }

    private var sandboxMode: String {
        switch permissionMode {
        case "plan": "read-only"
        case "bypassPermissions": "danger-full-access"
        default: "workspace-write"
        }
    }

    private func request(
        method: String, params: [String: Any] = [:], onResult: @escaping ([String: Any]) -> Void
    ) {
        let id = nextRequestId
        nextRequestId += 1
        pending[id] = onResult
        send(["id": id, "method": method, "params": params])
    }

    private func notify(method: String, params: [String: Any]) {
        send(["method": method, "params": params])
    }

    private func send(_ object: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: object) {
            var chunk = data
            chunk.append(0x0A)
            stdinPipe?.fileHandleForWriting.write(chunk)
        }
    }

    private func ingest(_ data: Data) {
        lineBuffer.append(data)
        while let nl = lineBuffer.firstIndex(of: 0x0A) {
            let line = lineBuffer.subdata(in: 0..<nl)
            lineBuffer.removeSubrange(0...nl)
            if line.isEmpty { continue }
            if let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any] {
                handle(obj)
            }
        }
    }

    private func handle(_ obj: [String: Any]) {
        if let method = obj["method"] as? String {
            if let id = obj["id"] {
                handleServerRequest(
                    id: id, method: method, params: (obj["params"] as? [String: Any]) ?? [:])
            } else {
                handleNotification(method: method, params: (obj["params"] as? [String: Any]) ?? [:])
            }
        } else if let id = obj["id"] as? Int {
            if let error = obj["error"] as? [String: Any] {
                emit(["type": "error", "message": error["message"] as? String ?? "codex_error"])
                pending.removeValue(forKey: id)
            } else {
                let result = (obj["result"] as? [String: Any]) ?? [:]
                pending.removeValue(forKey: id)?(result)
            }
        }
    }

    private func handleServerRequest(id: Any, method: String, params: [String: Any]) {
        if method == "item/commandExecution/requestApproval" {
            send(["id": id, "result": ["decision": permissionMode == "plan" ? "decline" : "accept"]])
        } else if method == "item/fileChange/requestApproval" {
            send(["id": id, "result": ["decision": permissionMode == "plan" ? "decline" : "accept"]])
        } else if method == "item/tool/requestUserInput" {
            send(["id": id, "result": ["answers": [:]]])
        } else if method == "item/tool/call" {
            send(["id": id, "result": ["contentItems": [], "success": false]])
        } else {
            send(["id": id, "error": ["code": -32601, "message": "unsupported_request"]])
        }
        if let itemId = params["itemId"] as? String {
            outputByItem[itemId] = method
        }
    }

    private func handleNotification(method: String, params: [String: Any]) {
        switch method {
        case "item/agentMessage/delta":
            if let itemId = params["itemId"] as? String,
                let delta = params["delta"] as? String
            {
                agentTextByItem[itemId, default: ""] += delta
                emitTextDelta(delta)
            }
        case "item/reasoning/textDelta", "item/reasoning/summaryTextDelta":
            if let delta = params["delta"] as? String {
                emitThinkingDelta(delta)
            }
        case "item/commandExecution/outputDelta", "item/fileChange/outputDelta":
            if let itemId = params["itemId"] as? String,
                let delta = params["delta"] as? String
            {
                outputByItem[itemId, default: ""] += delta
            }
        case "thread/tokenUsage/updated":
            updateUsage(params)
        case "item/started":
            handleStarted(params: params)
        case "item/completed":
            handleCompleted(params: params)
        case "thread/compacted":
            emit(["type": "status", "state": "compacting"])
        case "turn/completed":
            handleTurnCompleted(params)
        case "error":
            emit(["type": "error", "message": params["message"] as? String ?? "codex_error"])
        default:
            break
        }
    }

    private func handleStarted(params: [String: Any]) {
        if let item = params["item"] as? [String: Any] {
            if item["type"] as? String == "contextCompaction" {
                emit(["type": "status", "state": "compacting"])
            } else if let use = toolUse(for: item) {
                emitAssistant(toolUses: [use])
            }
        }
    }

    private func handleCompleted(params: [String: Any]) {
        if let item = params["item"] as? [String: Any],
            let itemId = item["id"] as? String,
            let type = item["type"] as? String
        {
            if type == "agentMessage" {
                let text = (item["text"] as? String) ?? agentTextByItem[itemId] ?? ""
                emitAssistant(text: text)
                agentTextByItem.removeValue(forKey: itemId)
            } else if toolTypes.contains(type) {
                emitToolResult(item: item)
            }
        }
    }

    private func handleTurnCompleted(_ params: [String: Any]) {
        if let turn = params["turn"] as? [String: Any],
            let status = turn["status"] as? String
        {
            if status == "failed" {
                let error = (turn["error"] as? [String: Any])?["message"] as? String
                emit(["type": "error", "message": error ?? "codex_turn_failed"])
            } else {
                if status == "interrupted" { emit(["type": "aborted"]) }
                emitResult()
            }
        }
        finish(exitCode: 0)
    }

    private func updateUsage(_ params: [String: Any]) {
        if let usage = params["tokenUsage"] as? [String: Any] {
            if let total = usage["total"] as? [String: Any] {
                contextTokens = total["totalTokens"] as? Int
            }
            contextWindow = usage["modelContextWindow"] as? Int
        }
    }

    private var toolTypes: Set<String> {
        ["commandExecution", "fileChange", "mcpToolCall", "dynamicToolCall", "webSearch"]
    }

    private func toolUse(for item: [String: Any]) -> [String: Any]? {
        if let type = item["type"] as? String, let id = item["id"] as? String {
            switch type {
            case "commandExecution":
                return [
                    "id": id,
                    "name": "Bash",
                    "input": ["command": item["command"] as? String ?? ""],
                ]
            case "fileChange":
                return [
                    "id": id,
                    "name": "Edit",
                    "input": ["file_path": fileChangeSummary(item["changes"] as? [[String: Any]] ?? [])],
                ]
            case "mcpToolCall":
                return [
                    "id": id,
                    "name": item["tool"] as? String ?? "MCP",
                    "input": (item["arguments"] as? [String: Any]) ?? [:],
                ]
            case "dynamicToolCall":
                return [
                    "id": id,
                    "name": item["tool"] as? String ?? "Tool",
                    "input": (item["arguments"] as? [String: Any]) ?? [:],
                ]
            case "webSearch":
                return [
                    "id": id,
                    "name": "WebSearch",
                    "input": ["query": item["query"] as? String ?? ""],
                ]
            default:
                return nil
            }
        }
        return nil
    }

    private func emitToolResult(item: [String: Any]) {
        if let id = item["id"] as? String,
            let type = item["type"] as? String
        {
            let failed =
                (item["status"] as? String == "failed") || (item["status"] as? String == "declined")
            let text = outputByItem[id] ?? completedText(item: item, type: type)
            emit([
                "event": [
                    "type": "user",
                    "message": [
                        "content": [
                            [
                                "type": "tool_result",
                                "tool_use_id": id,
                                "content": text,
                                "is_error": failed,
                            ]
                        ]
                    ],
                ]
            ])
            outputByItem.removeValue(forKey: id)
        }
    }

    private func completedText(item: [String: Any], type: String) -> String {
        switch type {
        case "commandExecution":
            return item["aggregatedOutput"] as? String ?? ""
        case "fileChange":
            return fileChangeSummary(item["changes"] as? [[String: Any]] ?? [])
        case "mcpToolCall":
            if let error = item["error"] as? [String: Any] {
                return error["message"] as? String ?? "\(error)"
            }
            return pretty(item["result"] ?? "")
        case "dynamicToolCall":
            return pretty(item["contentItems"] ?? "")
        case "webSearch":
            return item["query"] as? String ?? ""
        default:
            return ""
        }
    }

    private func fileChangeSummary(_ changes: [[String: Any]]) -> String {
        changes.compactMap { $0["path"] as? String }.joined(separator: "\n")
    }

    private func emitTextDelta(_ text: String) {
        emit([
            "event": [
                "type": "stream_event",
                "event": [
                    "type": "content_block_delta",
                    "delta": ["type": "text_delta", "text": text],
                ],
            ]
        ])
    }

    private func emitThinkingDelta(_ text: String) {
        emit([
            "event": [
                "type": "stream_event",
                "event": [
                    "type": "content_block_delta",
                    "delta": ["type": "thinking_delta", "thinking": text],
                ],
            ]
        ])
    }

    private func emitAssistant(text: String = "", toolUses: [[String: Any]] = []) {
        var content: [[String: Any]] = []
        if !text.isEmpty {
            content.append(["type": "text", "text": text])
        }
        for use in toolUses {
            content.append([
                "type": "tool_use",
                "id": use["id"] as? String ?? UUID().uuidString,
                "name": use["name"] as? String ?? "Tool",
                "input": use["input"] ?? [:],
            ])
        }
        if !content.isEmpty {
            var message: [String: Any] = [
                "model": model ?? "gpt-5.5",
                "content": content,
            ]
            if let contextTokens {
                message["usage"] = ["input_tokens": contextTokens]
            }
            emit(["event": ["type": "assistant", "message": message]])
        }
    }

    private func emitResult() {
        var event: [String: Any] = ["type": "result"]
        if let contextWindow {
            event["modelUsage"] = ["codex": ["contextWindow": contextWindow]]
        }
        emit(["event": event])
    }

    private func emit(_ partial: [String: Any]) {
        seq += 1
        var wrapped = partial
        wrapped["seq"] = seq
        wrapped["sessionId"] = sessionId
        if let payload = try? JSONSerialization.data(withJSONObject: wrapped) {
            var chunk = payload
            chunk.append(0x0A)
            ring.append((seq, chunk))
            if ring.count > maxRingSize { ring.removeFirst(ring.count - maxRingSize) }
            for sub in subscribers {
                sub.send(content: chunk, completion: .contentProcessed { _ in })
            }
        }
    }

    private func removeSubscriber(_ connection: NWConnection?) {
        if let connection {
            subscribers.removeAll { $0 === connection }
        }
    }

    private func finish(exitCode: Int32, terminatesProcess: Bool = true) {
        if hasExited { return }
        hasExited = true
        process?.terminationHandler = nil
        process?.standardOutput.flatMap { ($0 as? Pipe) }?.fileHandleForReading.readabilityHandler = nil
        process?.standardError.flatMap { ($0 as? Pipe) }?.fileHandleForReading.readabilityHandler = nil
        if terminatesProcess, let process, process.isRunning {
            process.terminate()
        }
        emit(["type": "exit", "code": Int(exitCode)])
        for sub in subscribers { sub.cancel() }
        subscribers.removeAll()
        onFinish?()
    }

    private func pretty(_ value: Any) -> String {
        if let string = value as? String { return string }
        if JSONSerialization.isValidJSONObject(value),
            let data = try? JSONSerialization.data(
                withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
            let text = String(data: data, encoding: .utf8)
        {
            return text
        }
        return "\(value)"
    }

    private struct Executable {
        let path: String
        let leadingArguments: [String]
    }

    private static func codexExecutable() -> Executable {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        var directories = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(
            String.init)
        for extra in [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "\(home)/.local/bin",
            "\(home)/.npm-global/bin",
        ] where !directories.contains(extra) {
            directories.append(extra)
        }
        for directory in directories {
            let candidate = "\(directory)/codex"
            if fileManager.isExecutableFile(atPath: candidate) {
                return Executable(path: candidate, leadingArguments: [])
            }
        }
        return Executable(path: "/usr/bin/env", leadingArguments: ["codex"])
    }

    private static func spawnEnvironment() -> [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        var env: [String: String] = [:]
        for key in ["HOME", "USER", "SHELL", "LANG", "LC_ALL", "TMPDIR", "TERM", "CODEX_HOME"] {
            if let value = inherited[key] { env[key] = value }
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var pathParts = (inherited["PATH"] ?? "").split(separator: ":").map(String.init)
        for extra in [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "\(home)/.local/bin",
            "\(home)/.npm-global/bin",
        ] where !pathParts.contains(extra) {
            pathParts.append(extra)
        }
        env["PATH"] = pathParts.joined(separator: ":")
        env["TERM"] = env["TERM"] ?? "xterm-256color"
        env["NO_COLOR"] = "1"
        return env
    }
}
