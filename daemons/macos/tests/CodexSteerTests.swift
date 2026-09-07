import CryptoKit
import Foundation

@main
struct CodexSteerTests {
    static func call(_ runner: CodexRunner, prompt: String, requestId: String) -> Result<[String: Any], Error> {
        let response = CodexTerminalRequest<[String: Any]>()
        runner.steer(prompt: prompt, requestId: requestId) { response.finish($0) }
        return response.wait()
    }

    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let requestId = UUID().uuidString
        let hash = Data(SHA256.hash(data: Data("hello".utf8))).map { String(format: "%02x", $0) }.joined()
        let url = root.appendingPathComponent("store.json")
        let store = CodexSteerReceiptStore(url: url)
        precondition(store.save(sessionId: "SESSION", requestId: requestId, hash: hash, status: "pending"))
        precondition(
            CodexSteerReceiptStore(url: url).status(
                sessionId: "session", requestId: requestId.lowercased(), prompt: "hello") == "pending")
        precondition(store.status(sessionId: "session", requestId: requestId, prompt: "different") == "mismatch")
        precondition(
            store.save(sessionId: "session", requestId: requestId.lowercased(), hash: hash, status: "accepted"))
        precondition(
            CodexSteerReceiptStore(url: url).status(sessionId: "SESSION", requestId: requestId, prompt: "hello")
                == "accepted")
        try JSONEncoder().encode(["SESSION:" + requestId.uppercased(): ["hash": hash, "status": "accepted"]]).write(
            to: url)
        precondition(
            CodexSteerReceiptStore(url: url).status(
                sessionId: "session", requestId: requestId.lowercased(), prompt: "hello") == "accepted")
        try JSONEncoder().encode([
            "SESSION:" + requestId.uppercased(): ["hash": hash, "status": "accepted"],
            "session:" + requestId.lowercased(): ["hash": hash, "status": "pending"],
        ]).write(to: url)
        precondition(!CodexSteerReceiptStore(url: url).available)
        try Data("corrupt".utf8).write(to: url)
        precondition(!CodexSteerReceiptStore(url: url).available)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        precondition(!CodexSteerReceiptStore(url: url).available)
        let blocked = root.appendingPathComponent("blocked")
        try Data("not a directory".utf8).write(to: blocked)
        let failed = CodexSteerReceiptStore(url: blocked.appendingPathComponent("receipts.json"))
        precondition(!failed.save(sessionId: "session", requestId: requestId, hash: hash, status: "pending"))
        precondition(!failed.available)
        precondition(failed.status(sessionId: "session", requestId: requestId, prompt: "hello") == "unavailable")
        for mode in ["accepted", "quota", "ambiguous", "write-failure"] {
            let receiptsURL = root.appendingPathComponent("receipts.json")
            if FileManager.default.fileExists(atPath: receiptsURL.path) {
                try FileManager.default.removeItem(at: receiptsURL)
            }
            try Data("accepted".utf8).write(to: root.appendingPathComponent("mode"))
            try Data().write(to: root.appendingPathComponent("calls"))
            let receipts = CodexSteerReceiptStore(url: receiptsURL)
            let client = CodexClient(executablePath: CommandLine.arguments[1], requestTimeout: 0.4)
            let queue = DispatchQueue(label: "afto.steer.fixture")
            let started = DispatchSemaphore(value: 0)
            client.observe(
                id: "started", on: queue,
                message: { message in
                    if message["method"] as? String == "turn/started" { started.signal() }
                }, disconnected: { _ in })
            let runner = CodexRunner(
                sessionId: mode, hasStartedBefore: false, model: nil, effort: nil, permissionMode: nil, threadId: nil,
                codex: client, steerReceipts: receipts, queue: queue)
            queue.async { runner.spawn(path: root.path, prompt: "fixture") }
            precondition(started.wait(timeout: .now() + 3) == .success)
            queue.sync {}
            try Data(mode.utf8).write(to: root.appendingPathComponent("mode"))
            let id = UUID().uuidString
            if mode == "quota" {
                if case .success = call(runner, prompt: "hello", requestId: id) { preconditionFailure("quota passed") }
                precondition(receipts.status(sessionId: mode, requestId: id, prompt: "hello") == nil)
                try Data("accepted".utf8).write(to: root.appendingPathComponent("mode"))
            }
            let responses = DispatchGroup()
            let outcomes = DispatchQueue(label: "afto.steer.outcomes")
            var accepted = 0
            for index in 0..<6 {
                responses.enter()
                runner.steer(prompt: "hello", requestId: index.isMultiple(of: 2) ? id : id.lowercased()) { result in
                    outcomes.sync { if case .success = result { accepted += 1 } }
                    responses.leave()
                }
            }
            precondition(responses.wait(timeout: .now() + 3) == .success)
            precondition(accepted == (["accepted", "quota"].contains(mode) ? 6 : 0), mode)
            if case .success = call(runner, prompt: "different", requestId: id) {
                preconditionFailure("conflicting payload passed")
            }
            let retried = call(runner, prompt: "hello", requestId: id)
            if ["ambiguous", "write-failure"].contains(mode) {
                if case .failure(let error) = retried {
                    precondition((error as NSError).code == 409)
                } else {
                    preconditionFailure("ambiguous retry passed")
                }
            }
            precondition(
                try! String(contentsOf: root.appendingPathComponent("calls"), encoding: .utf8).split(separator: "\n")
                    .count == 1)
            if mode == "write-failure" {
                precondition(!receipts.available)
                precondition(receipts.status(sessionId: mode, requestId: id, prompt: "hello") != "accepted")
                precondition(
                    CodexSteerReceiptStore(url: root.appendingPathComponent("saved-pending.json")).status(
                        sessionId: mode, requestId: id, prompt: "hello") == "pending")
            } else {
                precondition(
                    CodexSteerReceiptStore(url: receiptsURL).status(sessionId: mode, requestId: id, prompt: "hello")
                        == (mode == "ambiguous" ? "pending" : "accepted"))
            }
            let restarted = CodexRunner(
                sessionId: mode, hasStartedBefore: true, model: nil, effort: nil, permissionMode: nil, threadId: nil,
                codex: client, steerReceipts: CodexSteerReceiptStore(url: receiptsURL), queue: queue)
            if case .success = call(restarted, prompt: "hello", requestId: id) {
                precondition(["accepted", "quota"].contains(mode))
            } else {
                precondition(["ambiguous", "write-failure"].contains(mode))
            }
            client.stop()
            queue.sync {}
        }
        let head = HTTPRequest.parseHead(Data("POST /sessions/missing/steer HTTP/1.1\r\n\r\n".utf8))!
        for body: [String: Any] in [
            ["prompt": "legacy"], ["prompt": "legacy", "requestId": "bad"],
            ["prompt": String(repeating: "a", count: 32_769)],
        ] {
            let response = ChatHandler.steer(
                HTTPRequest(head: head, body: try JSONSerialization.data(withJSONObject: body)),
                params: ["id": "missing"])
            precondition(
                response.status == (body["requestId"] == nil && body["prompt"] as? String == "legacy" ? 409 : 400))
        }
        let settledSession = UUID().uuidString
        precondition(
            CodexSteerReceiptStore.shared.save(
                sessionId: settledSession, requestId: requestId, hash: hash, status: "accepted"))
        let replay = CodexTerminalRequest<[String: Any]>()
        precondition(
            RunnerManager.shared.steer(
                sessionId: settledSession, prompt: "hello", requestId: requestId.lowercased(),
                completion: { replay.finish($0) }))
        if case .failure = replay.wait() { preconditionFailure("accepted replay without active runner failed") }
        for (body, expected): ([String: Any], Int) in [
            (["prompt": "hello", "receiptOnly": true], 400),
            (["prompt": "hello", "requestId": requestId, "receiptOnly": 1], 400),
            (["prompt": "hello", "requestId": requestId, "receiptOnly": "true"], 400),
            (["prompt": "hello", "requestId": UUID().uuidString, "receiptOnly": true], 409),
            (["prompt": "hello", "requestId": requestId, "receiptOnly": true], 200),
            (["prompt": "changed", "requestId": requestId, "receiptOnly": true], 409),
        ] {
            let response = ChatHandler.steer(
                HTTPRequest(head: head, body: try JSONSerialization.data(withJSONObject: body)),
                params: ["id": settledSession])
            precondition(response.status == expected)
        }
        let pendingId = UUID().uuidString
        precondition(
            CodexSteerReceiptStore.shared.save(
                sessionId: settledSession, requestId: pendingId, hash: hash, status: "pending"))
        let pendingResponse = ChatHandler.steer(
            HTTPRequest(
                head: head,
                body: try JSONSerialization.data(withJSONObject: [
                    "prompt": "hello", "requestId": pendingId, "receiptOnly": true,
                ])), params: ["id": settledSession])
        precondition(pendingResponse.status == 409)
        print(
            "Native steering: durable pending before RPC, restart replay, unavailable storage, failed acceptance write, concurrent retries, payload conflict, UUID normalization and quota retry passed"
        )
    }
}
