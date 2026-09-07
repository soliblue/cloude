import CoreFoundation
import CryptoKit
import Foundation

enum CodexHandler {
    private static let threadSourceKinds = [
        "cli", "vscode", "exec", "appServer", "subAgent", "subAgentReview", "subAgentCompact",
        "subAgentThreadSpawn", "subAgentOther", "unknown",
    ]

    private static let mutationLock = NSLock()
    private static var pendingSessions: Set<String> = []
    static var transport: (String, [String: Any], @escaping (Result<[String: Any], Error>) -> Void) -> Void = {
        CodexClient.shared.request($0, params: $1, completion: $2)
    }

    static func isMutating(_ sessionId: String) -> Bool {
        mutationLock.lock()
        defer { mutationLock.unlock() }
        return pendingSessions.contains(sessionId.lowercased())
    }

    static func models(_ request: HTTPRequest) -> HTTPResponse { call("model/list", params: ["includeHidden": false]) }
    static func account(_ request: HTTPRequest) -> HTTPResponse {
        call("account/read", params: ["refreshToken": false])
    }
    static func login(_ request: HTTPRequest) -> HTTPResponse {
        if request.method == "GET" { return HTTPResponse.json(200, CodexLoginService.shared.status()) }
        if request.method == "DELETE" {
            let state = CodexLoginService.shared.cancel()
            return HTTPResponse.json(
                state["status"] as? String == "pending" && state["error"] != nil ? 502 : 200, state)
        }
        if request.method == "POST" {
            if request.body.isEmpty {
                let state = CodexLoginService.shared.start()
                return HTTPResponse.json(state["status"] as? String == "failed" ? 502 : 200, state)
            }
            if let body = body(request), body.keys.allSatisfy({ $0 == "type" }),
                body["type"] == nil || body["type"] as? String == "chatgptDeviceCode"
            {
                let state = CodexLoginService.shared.start()
                return HTTPResponse.json(state["status"] as? String == "failed" ? 502 : 200, state)
            }
            return HTTPResponse.json(400, ["error": "unsupported_login_type"])
        }
        return HTTPResponse.json(405, ["error": "method_not_allowed"])
    }
    static func limits(_ request: HTTPRequest) -> HTTPResponse { call("account/rateLimits/read", params: [:]) }
    static func modes(_ request: HTTPRequest) -> HTTPResponse { call("collaborationMode/list", params: [:]) }

    static func skills(_ request: HTTPRequest) -> HTTPResponse {
        call(
            "skills/list",
            params: [
                "cwds": request.query["path"].map { [($0 as NSString).expandingTildeInPath] } ?? [],
                "forceReload": request.query["reload"] == "true",
            ])
    }

    static func manifest(_ request: HTTPRequest) -> HTTPResponse {
        switch result(
            "skills/list",
            params: [
                "cwds": request.query["path"].map { [($0 as NSString).expandingTildeInPath] } ?? [],
                "forceReload": false,
            ])
        {
        case .success(let value):
            let skills = (value["data"] as? [[String: Any]] ?? []).flatMap { $0["skills"] as? [[String: Any]] ?? [] }
                .filter { $0["enabled"] as? Bool != false }
                .compactMap { skill -> [String: String]? in
                    if let name = skill["name"] as? String, let path = skill["path"] as? String {
                        return [
                            "name": name, "description": skill["description"] as? String ?? "", "path": path,
                            "icon": "sparkles",
                        ]
                    }
                    return nil
                }
            return HTTPResponse.json(
                200, ["skills": skills, "agents": [], "transcription": TranscribeHandler.available()])
        case .failure(let error): return failure(error)
        }
    }

    static func threads(_ request: HTTPRequest) -> HTTPResponse {
        guard validThreadQuery(request.query) else { return HTTPResponse.json(400, ["error": "invalid_thread_query"]) }
        let sectionId = request.query["sectionId"]
        var params: [String: Any] = [
            "limit": Int(request.query["limit"] ?? "50")!,
            "sortKey": sectionId == nil ? "updated_at" : "section_position",
            "sortDirection": sectionId == nil ? "desc" : "asc", "archived": request.query["archived"] == "true",
            "useStateDbOnly": request.query["refresh"] != "true",
        ]
        if let cursor = request.query["cursor"] { params["cursor"] = cursor }
        if let path = request.query["path"] { params["cwd"] = (path as NSString).expandingTildeInPath }
        if let search = request.query["search"] { params["searchTerm"] = search }
        if let sectionId {
            params["sectionId"] = sectionId
            params["sourceKinds"] = threadSourceKinds
        }
        if request.query["unsectioned"] == "true" {
            params["sectionId"] = NSNull()
            params["sourceKinds"] = threadSourceKinds
        }
        return call("thread/list", params: params)
    }

    private static func validThreadQuery(_ query: [String: String]) -> Bool {
        guard
            query.keys.allSatisfy({
                ["cursor", "limit", "path", "search", "archived", "refresh", "sectionId", "unsectioned"].contains($0)
            })
        else { return false }
        for key in ["cursor", "path", "search", "sectionId"] {
            if let value = query[key], !(key == "sectionId" ? identifier(value) : text(value, 4096)) { return false }
        }
        for key in ["archived", "refresh", "unsectioned"] {
            if let value = query[key], value != "true" && value != "false" { return false }
        }
        if query["sectionId"] != nil && query["unsectioned"] == "true" { return false }
        if let limit = query["limit"],
            !(limit == "100" || limit.range(of: "^[1-9][0-9]?$", options: .regularExpression) != nil)
        {
            return false
        }
        return true
    }

    private static func text(_ value: String, _ maximum: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= maximum
            && !value.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7f }
    }
    private static func identifier(_ value: String, _ maximum: Int = 512) -> Bool {
        text(value, maximum) && !value.contains(where: { $0 == "/" || $0 == "\\" })
    }

    static func history(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        switch result("thread/read", params: ["threadId": threadId(params), "includeTurns": true]) {
        case .success(let value):
            if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
                let etag = "\"\(SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())\""
                let unchanged = request.headers["if-none-match"] == etag
                return HTTPResponse(
                    status: unchanged ? 304 : 200, body: unchanged ? Data() : data,
                    extraHeaders: ["ETag": etag, "Cache-Control": "private, no-cache"])
            }
            return HTTPResponse.json(502, ["error": "invalid_codex_response"])
        case .failure(let error): return failure(error)
        }
    }

    static func fork(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let body = body(request), body["newSessionId"] == nil || body["newSessionId"] is String,
            body["path"] == nil || body["path"] is String,
            body["newSessionId"] as? String == nil || identifier(body["newSessionId"] as? String ?? ""),
            body["path"] as? String == nil
                || (body["path"] as? String)?.hasPrefix("/") == true && text(body["path"] as? String ?? "", 4096)
        {
            let sessionId = body["newSessionId"] as? String ?? UUID().uuidString
            if !identifier(sessionId, 200) {
                return HTTPResponse.json(400, ["error": "invalid_session_id"])
            }
            if !claim(sessionId) { return HTTPResponse.json(409, ["error": "session_conflict"]) }
            defer { release(sessionId) }
            if CodexSessionStore.shared.threadId(for: sessionId) != nil
                || RunnerManager.shared.isRunning(sessionId: sessionId)
                || RunnerManager.shared.isRunning(sessionId: params["id"] ?? "")
            {
                return HTTPResponse.json(409, ["error": "session_conflict"])
            }
            var forkParams: [String: Any] = ["threadId": threadId(params)]
            if let path = body["path"] as? String { forkParams["cwd"] = (path as NSString).expandingTildeInPath }
            switch result("thread/read", params: ["threadId": threadId(params), "includeTurns": false]) {
            case .failure(let error): return failure(error)
            case .success(let value):
                guard let source = value["thread"] as? [String: Any],
                    source["id"] as? String == threadId(params), !active(source)
                else { return HTTPResponse.json(409, ["error": "source_thread_changed"]) }
                switch result("thread/fork", params: forkParams) {
                case .success(let value):
                    if let thread = value["thread"] as? [String: Any], let id = thread["id"] as? String,
                        identifier(id), id != threadId(params), let cwd = thread["cwd"] as? String, text(cwd, 4096)
                    {
                        CodexSessionStore.shared.save(sessionId: sessionId, threadId: id, path: cwd)
                        return HTTPResponse.json(200, ["sessionId": sessionId, "threadId": id, "thread": thread])
                    }
                    return HTTPResponse.json(502, ["error": "invalid_codex_response"])
                case .failure(let error): return failure(error)
                }
            }
        }
        return HTTPResponse.json(400, ["error": "invalid_json_body"])
    }

    static func importThread(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let body = body(request), let id = body["threadId"] as? String, identifier(id),
            let sessionId = params["id"], !sessionId.isEmpty
        {
            if !claim(sessionId) { return HTTPResponse.json(409, ["error": "session_conflict"]) }
            defer { release(sessionId) }
            if CodexSessionStore.shared.threadId(for: sessionId) != nil
                || RunnerManager.shared.isRunning(sessionId: sessionId)
            {
                return HTTPResponse.json(409, ["error": "turn_already_running"])
            }
            switch result("thread/read", params: ["threadId": id, "includeTurns": true]) {
            case .success(let value):
                if let thread = value["thread"] as? [String: Any], let returnedId = thread["id"] as? String,
                    returnedId == id, let cwd = thread["cwd"] as? String, text(cwd, 4096)
                {
                    CodexSessionStore.shared.save(
                        sessionId: sessionId, threadId: id, path: cwd)
                    return HTTPResponse.json(200, ["sessionId": sessionId, "threadId": id, "thread": thread])
                }
                return HTTPResponse.json(502, ["error": "invalid_codex_response"])
            case .failure(let error): return failure(error)
            }
        }
        return HTTPResponse.json(400, ["error": "missing_thread_id"])
    }

    static func archive(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let body = body(request),
            body["archived"] == nil
                || (body["archived"] as? NSNumber).map({ CFGetTypeID($0) == CFBooleanGetTypeID() }) == true
        {
            let sessionId = params["id"] ?? ""
            if !claim(sessionId) { return HTTPResponse.json(409, ["error": "session_conflict"]) }
            defer { release(sessionId) }
            if RunnerManager.shared.isRunning(sessionId: sessionId) {
                return HTTPResponse.json(409, ["error": "turn_already_running"])
            }
            switch result("thread/read", params: ["threadId": threadId(params), "includeTurns": false]) {
            case .failure(let error): return failure(error)
            case .success(let value):
                guard let thread = value["thread"] as? [String: Any], thread["id"] as? String == threadId(params),
                    !active(thread)
                else { return HTTPResponse.json(409, ["error": "thread_changed"]) }
                return call(
                    body["archived"] as? Bool == false ? "thread/unarchive" : "thread/archive",
                    params: ["threadId": threadId(params)])
            }
        }
        return HTTPResponse.json(400, ["error": "invalid_json_body"])
    }

    static func rename(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let body = body(request), let name = body["name"] as? String,
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 200
        {
            return call(
                "thread/name/set",
                params: ["threadId": threadId(params), "name": name.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        return HTTPResponse.json(400, ["error": "invalid_name"])
    }

    static func goal(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if request.method == "GET" { return call("thread/goal/get", params: ["threadId": threadId(params)]) }
        if request.method == "DELETE" { return call("thread/goal/clear", params: ["threadId": threadId(params)]) }
        if let body = body(request), body["objective"] != nil || body["status"] != nil || body["tokenBudget"] != nil {
            var goal: [String: Any] = ["threadId": threadId(params)]
            if let objective = body["objective"] {
                if let text = objective as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    text.count <= 4000
                {
                    goal["objective"] = text.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    return HTTPResponse.json(400, ["error": "invalid_goal"])
                }
            }
            if let status = body["status"] {
                if let value = status as? String,
                    ["active", "paused", "blocked", "usageLimited", "budgetLimited", "complete"].contains(value)
                {
                    goal["status"] = value
                } else {
                    return HTTPResponse.json(400, ["error": "invalid_goal"])
                }
            }
            if let budget = body["tokenBudget"] {
                if budget is NSNull {
                    goal["tokenBudget"] = NSNull()
                } else if let value = budget as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
                    value.doubleValue > 0, value.doubleValue <= 9_007_199_254_740_991,
                    value.doubleValue.rounded(.towardZero) == value.doubleValue
                {
                    goal["tokenBudget"] = value
                } else {
                    return HTTPResponse.json(400, ["error": "invalid_goal"])
                }
            }
            return call("thread/goal/set", params: goal)
        }
        return HTTPResponse.json(400, ["error": "invalid_goal"])
    }

    static func projects(_ request: HTTPRequest) -> HTTPResponse {
        var params: [String: Any] = ["limit": 50]
        if let cursor = request.query["cursor"] { params["cursor"] = cursor }
        return call("project/list", params: params)
    }

    static func createProject(_ request: HTTPRequest) -> HTTPResponse {
        if let body = body(request), let name = body["name"] as? String,
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 200,
            let roots = body["roots"] as? [[String: Any]], !roots.isEmpty, roots.count <= 50,
            roots.allSatisfy({ ($0["path"] as? String)?.hasPrefix("/") == true }),
            body["idempotencyKey"] == nil || body["idempotencyKey"] is String
        {
            return call(
                "project/create",
                params: [
                    "idempotencyKey": body["idempotencyKey"] as? String ?? UUID().uuidString,
                    "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
                    "roots": roots.map { ["path": $0["path"] as! String] },
                ])
        }
        return HTTPResponse.json(400, ["error": "invalid_project"])
    }

    private static func claim(_ sessionId: String) -> Bool {
        mutationLock.lock()
        defer { mutationLock.unlock() }
        return pendingSessions.insert(sessionId.lowercased()).inserted
    }

    private static func active(_ thread: [String: Any]) -> Bool {
        (thread["status"] as? [String: Any])?["type"] as? String == "active"
    }

    private static func release(_ sessionId: String) {
        mutationLock.lock()
        defer { mutationLock.unlock() }
        pendingSessions.remove(sessionId.lowercased())
    }

    private static func body(_ request: HTTPRequest) -> [String: Any]? {
        guard request.body.count <= 64 * 1024 else { return nil }
        return (try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any]
    }

    private static func threadId(_ params: [String: String]) -> String {
        CodexSessionStore.shared.threadId(for: params["id"] ?? "") ?? params["id"] ?? ""
    }

    private static func failure(_ error: Error) -> HTTPResponse {
        HTTPResponse.json(
            error.localizedDescription.contains("timed out") ? 504 : 502,
            ["error": "codex_unavailable", "message": String(error.localizedDescription.prefix(2000))])
    }

    private static func call(_ method: String, params: [String: Any]) -> HTTPResponse {
        switch result(method, params: params) {
        case .success(let value): return HTTPResponse.json(200, value)
        case .failure(let error): return failure(error)
        }
    }

    private static func result(_ method: String, params: [String: Any]) -> Result<[String: Any], Error> {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var result: Result<[String: Any], Error> = .failure(
            NSError(domain: "Codex", code: 408, userInfo: [NSLocalizedDescriptionKey: "Codex \(method) timed out"]))
        transport(method, params) { value in
            lock.lock()
            result = value
            lock.unlock()
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 45)
        lock.lock()
        defer { lock.unlock() }
        return result
    }

    static func perform(_ method: String, params: [String: Any]) -> [String: Any]? {
        try? result(method, params: params).get()
    }
}
