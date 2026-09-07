import Foundation
import Network

@main struct HistoryPagesFixture {
    static func main() {
        let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLOUDE_DATA"]!)
        let calls = root.appendingPathComponent("calls.jsonl")
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        _ = FileManager.default.createFile(atPath: calls.path, contents: nil)
        CodexHandler.transport = { method, params, callback in
            let output = try! FileHandle(forWritingTo: calls)
            try! output.seekToEnd()
            try! output.write(contentsOf: JSONSerialization.data(withJSONObject: ["method": method, "params": params]))
            try! output.write(contentsOf: Data([10]))
            try! output.close()
            let id = params["threadId"] as! String
            if id == "racing" {
                precondition(
                    CodexSessionStore.shared.save(sessionId: "moving-alias", threadId: "changed", path: root.path))
            }
            if id == "provider-failure" {
                callback(
                    .failure(
                        NSError(
                            domain: "Fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "private-upstream-marker"]
                        )))
            } else {
                var turn: [String: Any] = [
                    "id": "turn-one", "status": "completed", "itemsView": "full",
                    "items": [
                        ["id": "item-one", "type": "agentMessage", "text": "Fixture result", "phase": "final_answer"]
                    ],
                ]
                if method == "thread/read" {
                    callback(
                        .success([
                            "thread": [
                                "id": id == "wrong-identity" ? "different" : id, "cwd": root.path,
                                "status": ["type": "idle"], "name": "Fixture task",
                                "turns": params["includeTurns"] as? Bool == true ? [turn] : [],
                            ]
                        ]))
                } else {
                    precondition(method == "thread/turns/list")
                    precondition(params["itemsView"] as? String == "full")
                    if id == "summary" || id == "notLoaded" { turn["itemsView"] = id }
                    if id == "bad-status" { turn["status"] = "unknown" }
                    if id == "bad-items" { turn["items"] = NSNull() }
                    if id == "bad-id" { turn["id"] = "" }
                    if id == "legacy" { turn.removeValue(forKey: "itemsView") }
                    var value: [String: Any] = [
                        "data": params["cursor"] == nil ? [turn] : [],
                        "nextCursor": params["cursor"] == nil ? "opaque:+/=" : NSNull(),
                        "backwardsCursor": params["cursor"] == nil ? "backwards:one" : NSNull(),
                    ]
                    if id == "duplicate" { value["data"] = [turn, turn] }
                    if id == "too-many" {
                        var other = turn
                        other["id"] = "other"
                        value["data"] = [turn, other]
                    }
                    if id == "missing-data" { value.removeValue(forKey: "data") }
                    if id == "bad-cursor" { value["nextCursor"] = [:] as [String: String] }
                    if id == "long-cursor" { value["nextCursor"] = String(repeating: "x", count: 4097) }
                    if id == "control-cursor" { value["backwardsCursor"] = "bad\n" }
                    if id == "legacy" {
                        value.removeValue(forKey: "nextCursor")
                        value.removeValue(forKey: "backwardsCursor")
                    }
                    callback(.success(value))
                }
            }
        }
        let listener = try! NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { HTTPConnection(connection: $0).start() }
        listener.stateUpdateHandler = { state in
            if case .ready = state {
                print("PORT \(listener.port!.rawValue)")
                fflush(stdout)
            }
        }
        listener.start(queue: .global())
        DispatchQueue.global().async {
            while let command = readLine() {
                if command == "stop" { exit(0) }
                if command == "reset" {
                    precondition(
                        CodexSessionStore.shared.save(sessionId: "moving-alias", threadId: "racing", path: root.path))
                } else if command == "storage-failure" {
                    let mapping = root.appendingPathComponent("codex-sessions.json")
                    try! FileManager.default.removeItem(at: mapping)
                    try! FileManager.default.createDirectory(at: mapping, withIntermediateDirectories: false)
                }
                print("DONE " + command)
                fflush(stdout)
            }
        }
        RunLoop.main.run()
    }
}
