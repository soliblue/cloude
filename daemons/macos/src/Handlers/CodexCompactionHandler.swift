import Foundation

enum CodexCompactionHandler {
    static func handle(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let sessionId = params["id"], let threadId = CodexSessionStore.shared.threadId(for: sessionId) {
            if request.method == "GET" {
                return HTTPResponse.json(200, CodexCompactionService.shared.snapshot(threadId: threadId))
            }
            if request.method == "POST",
                request.body.isEmpty
                    || (try? JSONSerialization.jsonObject(with: request.body) as? [String: Any])?.isEmpty == true
            {
                let result = CodexCompactionService.shared.start(threadId: threadId)
                return HTTPResponse.json(result.0, result.1)
            }
            return HTTPResponse.json(400, ["error": "Compaction accepts an empty request body only."])
        }
        return HTTPResponse.json(404, ["error": "Start or import a Codex task before compacting context."])
    }
}
