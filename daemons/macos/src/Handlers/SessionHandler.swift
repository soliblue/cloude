import Foundation

enum SessionHandler {
    static func updateTitle(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let sessionId = params["id"],
            let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
            let path = body["path"] as? String
        {
            if let threadId = CodexSessionStore.shared.threadId(for: sessionId),
                let result = CodexHandler.perform(
                    "thread/read", params: ["threadId": threadId, "includeTurns": false]),
                let thread = result["thread"] as? [String: Any]
            {
                let title = (thread["name"] as? String) ?? (thread["preview"] as? String) ?? "Codex task"
                return HTTPResponse.json(
                    200,
                    [
                        "title": String(title.split(separator: "\n").first?.prefix(60) ?? "Codex task"),
                        "symbol": "terminal",
                    ])
            }
            let transcript = readTranscript(path: path, sessionId: sessionId)
            if !transcript.isEmpty {
                return HTTPResponse.json(
                    200,
                    [
                        "title": String(
                            transcript.split(separator: "\n").first?.replacingOccurrences(of: "user: ", with: "")
                                .prefix(60) ?? "Task"), "symbol": "terminal",
                    ])
            }
            return HTTPResponse.json(404, ["error": "transcript_not_found"])
        }
        return HTTPResponse.json(400, ["error": "missing_params"])
    }

    private static func readTranscript(path: String, sessionId: String) -> String {
        let encoded =
            path
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ".", with: "-")
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent(".claude/projects/\(encoded)/\(sessionId.lowercased()).jsonl")
        if let data = try? Data(contentsOf: url),
            let text = String(data: data, encoding: .utf8)
        {
            var lines: [String] = []
            for raw in text.split(separator: "\n") {
                if let lineData = raw.data(using: .utf8),
                    let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                    let message = obj["message"] as? [String: Any],
                    let role = message["role"] as? String
                {
                    if let str = message["content"] as? String {
                        lines.append("\(role): \(str)")
                    } else if let blocks = message["content"] as? [[String: Any]] {
                        for block in blocks {
                            if let type = block["type"] as? String, type == "text",
                                let str = block["text"] as? String
                            {
                                lines.append("\(role): \(str)")
                            }
                        }
                    }
                }
            }
            return lines.joined(separator: "\n\n")
        }
        return ""
    }

}
