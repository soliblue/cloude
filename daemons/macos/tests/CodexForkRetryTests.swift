import Darwin
import Foundation

@main
struct CodexForkRetryTests {
    static func request(path: String? = nil) -> HTTPRequest {
        var body = ["newSessionId": "TARGET"]
        if let path { body["path"] = path }
        return HTTPRequest(
            head: HTTPRequest.parseHead(Data("POST /fixture HTTP/1.1\r\n\r\n".utf8))!,
            body: try! JSONSerialization.data(withJSONObject: body))
    }

    static func json(_ response: HTTPResponse) -> [String: Any] {
        if case .buffered(let data) = response.body {
            return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        }
        preconditionFailure("buffered response required")
    }

    static func run(_ mode: String, root: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = [mode, root.path]
        process.environment = ProcessInfo.processInfo.environment.merging(["CLOUDE_DATA": root.path]) { _, new in new }
        try process.run()
        process.waitUntilExit()
        precondition(process.terminationStatus == 0, mode)
    }

    static func main() throws {
        if CommandLine.arguments.count == 1 {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(
                "afto-fork-retry-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            for mode in [
                "success", "ambiguous", "completed-write-failure", "mapping-failure", "pending-write-failure",
                "corrupt", "concurrent",
            ] {
                let state = root.appendingPathComponent(mode)
                try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
                try run(mode, root: state)
                if ["success", "mapping-failure"].contains(mode) {
                    try JSONSerialization.data(withJSONObject: [
                        "source": ["threadId": "source-thread", "path": state.path]
                    ]).write(to: state.appendingPathComponent("codex-sessions.json"))
                    try run("replay", root: state)
                }
                if ["ambiguous", "completed-write-failure"].contains(mode) { try run("unknown", root: state) }
            }
            var synced: [String] = []
            let nested = root.appendingPathComponent("fresh-parent/fresh-child/receipt.json")
            precondition(
                CodexPersistence.write(Data("pending".utf8), to: nested, exclusive: true) { descriptor in
                    var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
                    precondition(fcntl(descriptor, F_GETPATH, &buffer) == 0)
                    synced.append(URL(fileURLWithPath: String(cString: buffer)).resolvingSymlinksInPath().path)
                    return fsync(descriptor) == 0
                })
            precondition(
                synced
                    == [
                        nested, nested.deletingLastPathComponent(),
                        nested.deletingLastPathComponent().deletingLastPathComponent(), root,
                    ].map { $0.resolvingSymlinksInPath().path })
            var synchronizations = 0
            precondition(
                !CodexPersistence.write(
                    Data("pending".utf8), to: root.appendingPathComponent("failed-parent/receipt.json"), exclusive: true
                ) { descriptor in
                    synchronizations += 1
                    return synchronizations < 3 && fsync(descriptor) == 0
                })
            precondition(synchronizations == 3)
            let corrupt = root.appendingPathComponent("corrupt-mappings.json")
            try Data("broken".utf8).write(to: corrupt)
            let unavailable = CodexSessionStore(url: corrupt)
            precondition(!unavailable.available)
            precondition(!unavailable.save(sessionId: "new", threadId: "new-thread", path: root.path))
            precondition(unavailable.threadId(for: "new") == nil)
            print(
                "Native durable forks: fresh-process replay and missing-map repair, changed scope conflict, exclusive pending, ambiguous restart, corrupt storage, failed pending/completed/mapping writes, and concurrent dedup passed"
            )
            return
        }
        let mode = CommandLine.arguments[1]
        let root = URL(fileURLWithPath: CommandLine.arguments[2])
        let mappings = root.appendingPathComponent("codex-sessions.json")
        let receipt = CodexHandler.forkReceipts.url(sessionId: "target")
        let params = ["id": "SOURCE"]
        var forkCalls = 0
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        if !["replay", "unknown"].contains(mode) {
            precondition(CodexSessionStore.shared.save(sessionId: "source", threadId: "source-thread", path: root.path))
        }
        if mode == "pending-write-failure" { try Data("blocked".utf8).write(to: CodexHandler.forkReceipts.directory) }
        if mode == "corrupt" {
            try FileManager.default.createDirectory(
                at: receipt.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("corrupt".utf8).write(to: receipt)
        }
        CodexHandler.transport = { method, _, callback in
            precondition(!["replay", "unknown", "corrupt"].contains(mode), "retry reached provider")
            if method == "thread/read" {
                callback(
                    .success([
                        "thread": [
                            "id": "source-thread", "cwd": root.path,
                            "turns": [["id": "finished", "status": "completed"]],
                        ]
                    ]))
            } else {
                precondition(method == "thread/fork")
                forkCalls += 1
                let pending = CodexForkReceiptStore(directory: CodexHandler.forkReceipts.directory).value(
                    sessionId: "target")
                precondition(pending?["status"] as? String == "pending")
                precondition(
                    !CodexHandler.forkReceipts.save(sessionId: "target", hash: String(repeating: "a", count: 64)))
                precondition(
                    CodexHandler.forkReceipts.value(sessionId: "target")?["hash"] as? String == pending?["hash"]
                        as? String)
                precondition(
                    (try! FileManager.default.attributesOfItem(atPath: receipt.path)[.posixPermissions] as! NSNumber)
                        .intValue == 0o600)
                precondition(
                    (try! FileManager.default.attributesOfItem(atPath: receipt.deletingLastPathComponent().path)[
                        .posixPermissions] as! NSNumber).intValue == 0o700)
                if mode == "concurrent" {
                    entered.signal()
                    precondition(release.wait(timeout: .now() + 3) == .success)
                }
                if mode == "ambiguous" {
                    callback(.failure(NSError(domain: "fixture", code: 1)))
                    return
                }
                if mode == "completed-write-failure" {
                    try! FileManager.default.moveItem(at: receipt, to: root.appendingPathComponent("pending.json"))
                    try! FileManager.default.createDirectory(at: receipt, withIntermediateDirectories: false)
                }
                if mode == "mapping-failure" {
                    try! FileManager.default.moveItem(at: mappings, to: root.appendingPathComponent("mappings.json"))
                    try! FileManager.default.createDirectory(at: mappings, withIntermediateDirectories: false)
                }
                callback(
                    .success([
                        "thread": [
                            "id": "child", "cwd": root.path,
                            "turns": [
                                [
                                    "id": "finished", "status": "completed",
                                    "items": [["type": "agentMessage", "text": "original"]],
                                ]
                            ],
                        ]
                    ]))
            }
        }
        if mode == "replay" {
            RunnerManager.shared.active = ["target"]
            precondition(json(CodexHandler.fork(request(), params: params))["code"] as? String == "fork_conflict")
            RunnerManager.shared.active = []
        }
        var response: HTTPResponse
        if mode == "concurrent" {
            let finished = DispatchSemaphore(value: 0)
            var first: HTTPResponse?
            DispatchQueue.global().async {
                first = CodexHandler.fork(request(), params: params)
                finished.signal()
            }
            precondition(entered.wait(timeout: .now() + 3) == .success)
            let pending = CodexHandler.fork(request(), params: params)
            precondition(
                pending.status == 409 && json(pending)["code"] as? String == "fork_pending"
                    && json(pending)["retriable"] as? Bool == true)
            precondition(
                json(CodexHandler.fork(request(path: "/different"), params: params))["code"] as? String
                    == "fork_conflict")
            release.signal()
            precondition(finished.wait(timeout: .now() + 3) == .success)
            response = first!
        } else {
            response = CodexHandler.fork(request(), params: params)
        }
        if ["success", "replay", "concurrent"].contains(mode) {
            precondition(response.status == 200)
            precondition(CodexSessionStore(url: mappings).threadId(for: "target") == "child")
            let original = try JSONSerialization.data(withJSONObject: json(response), options: [.sortedKeys])
            if mode == "replay" {
                precondition(try! Data(contentsOf: root.appendingPathComponent("response.json")) == original)
            } else {
                try original.write(to: root.appendingPathComponent("response.json"))
            }
            precondition(
                json(CodexHandler.fork(request(path: "/different"), params: params))["code"] as? String
                    == "fork_conflict")
            precondition(
                json(CodexHandler.fork(request(), params: ["id": "other-source"]))["code"] as? String == "fork_conflict"
            )
            let replay = CodexHandler.fork(request(), params: params)
            precondition(replay.status == 200)
            precondition(try! JSONSerialization.data(withJSONObject: json(replay), options: [.sortedKeys]) == original)
            precondition(CodexSessionStore.shared.save(sessionId: "target", threadId: "another-child", path: root.path))
            precondition(json(CodexHandler.fork(request(), params: params))["code"] as? String == "fork_conflict")
            precondition(CodexSessionStore.shared.save(sessionId: "target", threadId: "child", path: root.path))
            precondition(
                CodexSessionStore.shared.save(sessionId: "source", threadId: "changed-source", path: root.path))
            precondition(json(CodexHandler.fork(request(), params: params))["code"] as? String == "fork_conflict")
            precondition(forkCalls == (mode == "replay" ? 0 : 1))
        } else if mode == "mapping-failure" {
            precondition(response.status == 503 && forkCalls == 1)
            precondition(CodexSessionStore.shared.threadId(for: "target") == nil)
            precondition(CodexHandler.forkReceipts.value(sessionId: "target")?["status"] as? String == "completed")
            try JSONSerialization.data(
                withJSONObject: CodexHandler.forkReceipts.value(sessionId: "target")!["response"]!,
                options: [.sortedKeys]
            ).write(to: root.appendingPathComponent("response.json"))
            try FileManager.default.removeItem(at: mappings)
            try FileManager.default.moveItem(at: root.appendingPathComponent("mappings.json"), to: mappings)
        } else if mode == "completed-write-failure" {
            precondition(response.status == 502 && forkCalls == 1)
            precondition(CodexSessionStore.shared.threadId(for: "target") == nil)
            try FileManager.default.removeItem(at: receipt)
            try FileManager.default.moveItem(at: root.appendingPathComponent("pending.json"), to: receipt)
        } else if ["pending-write-failure", "corrupt"].contains(mode) {
            precondition(response.status == 503 && forkCalls == 0)
            precondition(json(response)["code"] as? String == "fork_storage_unavailable")
        } else {
            precondition(response.status == (mode == "unknown" ? 409 : 502))
            precondition(
                json(response)["code"] as? String == "fork_outcome_unknown"
                    && json(response)["retriable"] as? Bool == false)
            precondition(forkCalls == (mode == "unknown" ? 0 : 1))
        }
    }
}
