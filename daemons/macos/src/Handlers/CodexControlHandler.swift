import Foundation

enum CodexControlHandler {
    static func abort(sessionId: String) -> HTTPResponse {
        if let threadId = CodexSessionStore.shared.threadId(for: sessionId) {
            if let result = CodexHandler.perform("thread/read", params: ["threadId": threadId, "includeTurns": true]),
                let thread = result["thread"] as? [String: Any], thread["id"] as? String == threadId
            {
                if (thread["status"] as? [String: Any])?["type"] as? String == "active" {
                    if let turn = (thread["turns"] as? [[String: Any]])?.last,
                        turn["status"] as? String == "inProgress", let turnId = turn["id"] as? String, !turnId.isEmpty
                    {
                        if CodexHandler.perform("turn/interrupt", params: ["threadId": threadId, "turnId": turnId])
                            != nil
                        {
                            return HTTPResponse.json(200, ["ok": true, "aborted": true])
                        }
                        return HTTPResponse.json(
                            502, ["error": "Codex did not confirm interruption. Refresh the task and retry."])
                    }
                    return HTTPResponse.json(
                        409, ["error": "The active turn changed. Refresh the task before stopping it."])
                }
                return HTTPResponse.json(200, ["ok": true, "aborted": false])
            }
            return HTTPResponse.json(
                502, ["error": "Could not read this Codex task. Check the host connection and retry."])
        }
        return HTTPResponse.json(200, ["ok": true, "aborted": false])
    }
}
