import Foundation

enum CodexSectionHandler {
    static let threadSourceKinds = [
        "cli", "vscode", "exec", "appServer", "subAgent", "subAgentReview", "subAgentCompact",
        "subAgentThreadSpawn", "subAgentOther", "unknown",
    ]

    static func sections(_ request: HTTPRequest) -> HTTPResponse {
        if request.method == "GET" {
            guard page(request.query) else { return invalid() }
            var params: [String: Any] = ["limit": Int(request.query["limit"] ?? "50")!]
            if let cursor = request.query["cursor"] { params["cursor"] = cursor }
            return perform("threadSection/list", params: params)
        }
        guard let value = body(request), fields(value, ["name", "appearance"]), let name = value["name"] as? String,
            text(name, 120), appearance(value["appearance"])
        else { return invalid() }
        var params: [String: Any] = ["name": name.trimmingCharacters(in: .whitespacesAndNewlines)]
        if let appearance = value["appearance"] { params["appearance"] = appearance }
        return perform("threadSection/create", params: params)
    }

    static func update(_ request: HTTPRequest, params path: [String: String]) -> HTTPResponse {
        guard let id = path["id"], identifier(id), let value = body(request), fields(value, ["name", "appearance"]),
            let name = value["name"] as? String, text(name, 120), appearance(value["appearance"])
        else { return invalid() }
        var arguments: [String: Any] = ["sectionId": id, "name": name.trimmingCharacters(in: .whitespacesAndNewlines)]
        if let appearance = value["appearance"] { arguments["appearance"] = appearance }
        return perform("threadSection/update", params: arguments)
    }

    static func delete(_ request: HTTPRequest, params path: [String: String]) -> HTTPResponse {
        guard let id = path["id"], identifier(id), request.query.isEmpty,
            request.body.isEmpty || body(request)?.isEmpty == true
        else { return invalid() }
        return perform("threadSection/delete", params: ["sectionId": id])
    }

    static func move(_ request: HTTPRequest, params path: [String: String]) -> HTTPResponse {
        guard let value = body(request), fields(value, ["sectionId", "beforeThreadId"]),
            value["sectionId"] is NSNull || identifier(value["sectionId"]),
            value["beforeThreadId"] == nil || value["beforeThreadId"] is NSNull || identifier(value["beforeThreadId"])
        else { return invalid() }
        let sessionId = path["id"] ?? ""
        let threadId = CodexSessionStore.shared.threadId(for: sessionId) ?? sessionId
        var arguments: [String: Any] = [
            "threadId": threadId, "sectionId": value["sectionId"] is NSNull ? NSNull() : value["sectionId"]!,
        ]
        if let before = value["beforeThreadId"] { arguments["beforeThreadId"] = before }
        return perform("thread/section/move", params: arguments)
    }

    static func threads(_ request: HTTPRequest, params path: [String: String]) -> HTTPResponse {
        guard let id = path["id"], identifier(id), page(request.query) else { return invalid() }
        var arguments: [String: Any] = [
            "sectionId": id, "sourceKinds": threadSourceKinds, "sortKey": "section_position", "sortDirection": "asc",
            "useStateDbOnly": true,
            "limit": Int(request.query["limit"] ?? "50")!,
        ]
        if let cursor = request.query["cursor"] { arguments["cursor"] = cursor }
        return perform("thread/list", params: arguments)
    }

    private static func perform(_ method: String, params: [String: Any]) -> HTTPResponse {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var result: Result<[String: Any], Error> = .failure(NSError(domain: "Codex", code: 408))
        CodexHandler.transport(method, params) { value in
            lock.lock()
            result = value
            lock.unlock()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 45)
        lock.lock()
        defer { lock.unlock() }
        switch result {
        case .success(let value): return HTTPResponse.json(200, value)
        case .failure: return HTTPResponse.json(502, ["error": "codex_request_failed", "method": method])
        }
    }

    private static func body(_ request: HTTPRequest) -> [String: Any]? {
        guard request.body.count <= 16_384 else { return nil }
        return try? JSONSerialization.jsonObject(with: request.body) as? [String: Any]
    }
    private static func invalid() -> HTTPResponse { HTTPResponse.json(400, ["error": "invalid_codex_section_request"]) }
    private static func fields(_ value: [String: Any], _ allowed: [String]) -> Bool {
        value.keys.allSatisfy { allowed.contains($0) }
    }
    private static func text(_ value: Any?, _ maximum: Int = 512) -> Bool {
        guard let value = value as? String else { return false }
        return text(value, maximum)
    }
    private static func text(_ value: String, _ maximum: Int) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= maximum
            && !value.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7f }
    }
    private static func identifier(_ value: Any?) -> Bool {
        guard let value = value as? String, text(value) else { return false }
        return !value.contains(where: { $0 == "/" || $0 == "\\" })
    }
    private static func appearance(_ value: Any?) -> Bool {
        guard let value else { return true }
        if value is NSNull { return true }
        guard let value = value as? [String: Any], fields(value, ["color", "icon"]) else { return false }
        return ["color", "icon"].allSatisfy { value[$0] == nil || value[$0] is NSNull || text(value[$0], 128) }
    }
    private static func page(_ query: [String: String]) -> Bool {
        guard query.keys.allSatisfy({ ["cursor", "limit"].contains($0) }),
            query["cursor"] == nil || text(query["cursor"], 4096)
        else { return false }
        guard let limit = query["limit"] else { return true }
        return limit == "100" || limit.range(of: "^[1-9][0-9]?$", options: .regularExpression) != nil
    }
}
