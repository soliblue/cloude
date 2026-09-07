import Foundation

enum CodexAttentionHandler {
    static func batch(_ request: HTTPRequest) -> HTTPResponse {
        if request.body.count > 524_288 { return HTTPResponse.json(413, ["error": "payload_too_large"]) }
        if let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
            body.keys.count == 1, let sessionIds = body["sessionIds"] as? [String], sessionIds.count <= 100,
            Set(sessionIds.map { Data($0.utf8) }).count == sessionIds.count,
            sessionIds.allSatisfy({
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf16.count <= 512
                    && !$0.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7f }
            })
        {
            return HTTPResponse.json(
                200,
                [
                    "sessions": sessionIds.map { sessionId -> [String: Any] in
                        let threadId = CodexSessionStore.shared.threadId(for: sessionId) ?? sessionId
                        return [
                            "sessionId": sessionId, "threadId": threadId,
                            "requests": CodexClient.shared.pendingRequests(threadId: threadId),
                            "agentAttention": CodexClient.shared.attentionForThread(threadId),
                        ]
                    }
                ])
        }
        return HTTPResponse.json(400, ["error": "invalid_codex_attention_request"])
    }
}
