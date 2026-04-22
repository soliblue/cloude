import Foundation
import Network

enum SessionJSONLReplay {
    static func replay(sessionId: String, to connection: NWConnection) -> Bool {
        if let lines = loadLastTurn(sessionId: sessionId) {
            var seq = 0
            var batch = Data()
            for line in lines {
                if let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) {
                    seq += 1
                    let wrapped: [String: Any] = [
                        "event": obj, "seq": seq, "sessionId": sessionId,
                    ]
                    if let payload = try? JSONSerialization.data(withJSONObject: wrapped) {
                        batch.append(payload)
                        batch.append(0x0A)
                    }
                }
            }
            seq += 1
            let tail: [String: Any] = [
                "type": "exit", "code": 0, "seq": seq, "sessionId": sessionId,
            ]
            if let payload = try? JSONSerialization.data(withJSONObject: tail) {
                batch.append(payload)
                batch.append(0x0A)
            }
            connection.send(
                content: batch,
                completion: .contentProcessed { _ in connection.cancel() })
            return true
        }
        return false
    }

    private static func loadLastTurn(sessionId: String) -> [String]? {
        let projects = NSString("~/.claude/projects").expandingTildeInPath
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: projects) {
            for folder in entries {
                let path = "\(projects)/\(folder)/\(sessionId).jsonl"
                if let text = try? String(contentsOfFile: path, encoding: .utf8) {
                    return extractLastTurn(
                        lines: text.split(separator: "\n", omittingEmptySubsequences: true).map(
                            String.init))
                }
            }
        }
        return nil
    }

    private static func extractLastTurn(lines: [String]) -> [String] {
        var cut = 0
        for (index, line) in lines.enumerated().reversed() {
            if isUserPromptEntry(line) {
                cut = index
                break
            }
        }
        return Array(lines[cut..<lines.count])
    }

    private static func isUserPromptEntry(_ line: String) -> Bool {
        if let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
            obj["type"] as? String == "user",
            let message = obj["message"] as? [String: Any]
        {
            if let content = message["content"] as? String, !content.isEmpty { return true }
            if let blocks = message["content"] as? [[String: Any]] {
                for block in blocks where block["type"] as? String == "text" { return true }
            }
        }
        return false
    }
}
