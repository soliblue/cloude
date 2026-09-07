import Foundation

enum CodexPluginHandler {
    static var transport: (String, [String: Any], @escaping (Result<[String: Any], Error>) -> Void) -> Void = {
        CodexClient.shared.request($0, params: $1, completion: $2)
    }

    static func plugins(_ request: HTTPRequest) -> HTTPResponse {
        let query = request.query
        if fields(query, ["path", "installed", "forceRefetch"]), boolean(query["installed"]),
            boolean(query["forceRefetch"]),
            query["path"] == nil || validPath(query["path"]),
            !(query["installed"] == "true" && query["forceRefetch"] != nil)
        {
            return perform(
                query["installed"] == "true" ? "plugin/installed" : "plugin/list",
                params: query["installed"] == "true"
                    ? ["cwds": query["path"].map { [absolute($0)] } ?? []]
                    : [
                        "cwds": query["path"].map { [absolute($0)] } ?? [],
                        "forceRefetch": query["forceRefetch"] == "true",
                    ])
        }
        return HTTPResponse.json(400, ["error": "invalid_plugin_query"])
    }

    static func plugin(_ request: HTTPRequest) -> HTTPResponse {
        let value = request.method == "GET" ? request.query : body(request)
        if request.method == "DELETE" {
            if fields(value, ["pluginId"]), text(value["pluginId"], 512) {
                return perform("plugin/uninstall", params: ["pluginId": value["pluginId"]!])
            }
            return HTTPResponse.json(400, ["error": "invalid_plugin_id"])
        }
        let allowed =
            request.method == "POST"
            ? ["pluginName", "marketplacePath", "remoteMarketplaceName", "installAttemptId"]
            : ["pluginName", "marketplacePath", "remoteMarketplaceName"]
        if fields(value, allowed), identity(value),
            request.method != "POST" || value["installAttemptId"] == nil || text(value["installAttemptId"], 128)
        {
            var params = parameters(value)
            if let attempt = value["installAttemptId"] { params["installAttemptId"] = attempt }
            return perform(request.method == "POST" ? "plugin/install" : "plugin/read", params: params)
        }
        return HTTPResponse.json(400, ["error": "invalid_plugin_identity"])
    }

    static func apps(_ request: HTTPRequest) -> HTTPResponse {
        let query = request.query
        if query["installed"] == "true" {
            if fields(query, ["installed", "threadId", "forceRefresh"]), boolean(query["forceRefresh"]),
                query["threadId"] == nil || text(query["threadId"])
            {
                var params: [String: Any] = ["forceRefresh": query["forceRefresh"] == "true"]
                if let threadId = query["threadId"] { params["threadId"] = threadId }
                return perform(
                    "app/installed",
                    params: params)
            }
        } else if query["installed"] == nil || query["installed"] == "false",
            page(query, ["installed", "threadId", "cursor", "limit", "forceRefetch"]),
            boolean(query["forceRefetch"])
        {
            var params: [String: Any] = [
                "limit": Int(query["limit"] ?? "50")!, "forceRefetch": query["forceRefetch"] == "true",
            ]
            if let cursor = query["cursor"] { params["cursor"] = cursor }
            if let threadId = query["threadId"] { params["threadId"] = threadId }
            return perform(
                "app/list",
                params: params)
        }
        return HTTPResponse.json(400, ["error": "invalid_app_query"])
    }

    static func readApps(_ request: HTTPRequest) -> HTTPResponse {
        let value = body(request)
        if fields(value, ["appIds", "includeTools", "threadId"]), let ids = value["appIds"] as? [String],
            !ids.isEmpty, ids.count <= 100, ids.allSatisfy({ text($0) }),
            value["includeTools"] == nil || value["includeTools"] is Bool,
            value["threadId"] == nil || text(value["threadId"])
        {
            var params: [String: Any] = [
                "appIds": Array(NSOrderedSet(array: ids)) as! [String],
                "includeTools": value["includeTools"] as? Bool ?? false,
            ]
            if let threadId = value["threadId"] as? String { params["threadId"] = threadId }
            return perform(
                "app/read",
                params: params)
        }
        return HTTPResponse.json(400, ["error": "invalid_app_ids"])
    }

    static func mcp(_ request: HTTPRequest) -> HTTPResponse {
        let query = request.query
        if page(query, ["threadId", "cursor", "limit", "detail"]),
            query["detail"] == nil || query["detail"] == "toolsAndAuthOnly"
        {
            var params: [String: Any] = ["detail": "toolsAndAuthOnly", "limit": Int(query["limit"] ?? "50")!]
            if let cursor = query["cursor"] { params["cursor"] = cursor }
            if let threadId = query["threadId"] { params["threadId"] = threadId }
            return perform(
                "mcpServerStatus/list",
                params: params)
        }
        return HTTPResponse.json(400, ["error": "invalid_mcp_query"])
    }

    private static func perform(_ method: String, params: [String: Any]) -> HTTPResponse {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var result: Result<[String: Any], Error> = .failure(NSError(domain: "Codex", code: 408))
        let finish: (Result<[String: Any], Error>) -> Void = { value in
            lock.lock()
            result = value
            lock.unlock()
            semaphore.signal()
        }
        let recoverable = ["app/list", "app/installed", "app/read", "mcpServerStatus/list"].contains(method)
        let threadId = params["threadId"] as? String
        var submit: ((String, [String: Any], Bool) -> Void)!
        submit = { requestMethod, requestParams, recovered in
            transport(requestMethod, requestParams) { value in
                switch value {
                case .success:
                    finish(value)
                case .failure(let error)
                where recoverable && !recovered && threadId != nil
                    && error.localizedDescription == "thread not found: \(threadId!)":
                    transport("thread/read", ["threadId": threadId!, "includeTurns": false]) { readValue in
                        switch readValue {
                        case .failure:
                            finish(readValue)
                        case .success:
                            transport("thread/resume", ["threadId": threadId!]) { resumeValue in
                                switch resumeValue {
                                case .failure:
                                    finish(resumeValue)
                                case .success:
                                    submit(requestMethod, requestParams, true)
                                }
                            }
                        }
                    }
                case .failure:
                    finish(value)
                }
            }
        }
        submit(method, params, false)
        _ = semaphore.wait(timeout: .now() + 45)
        lock.lock()
        defer { lock.unlock() }
        switch result {
        case .success(let value): return HTTPResponse.json(200, value)
        case .failure: return HTTPResponse.json(502, ["error": "codex_request_failed", "method": method])
        }
    }

    private static func body(_ request: HTTPRequest) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any] ?? [:]
    }

    private static func fields(_ value: [String: Any], _ allowed: [String]) -> Bool {
        value.keys.allSatisfy { allowed.contains($0) }
    }
    private static func fields(_ value: [String: String], _ allowed: [String]) -> Bool {
        value.keys.allSatisfy { allowed.contains($0) }
    }
    private static func text(_ value: Any?, _ maximum: Int = 512) -> Bool {
        guard let value = value as? String else { return false }
        return text(value, maximum)
    }
    private static func text(_ value: String?, _ maximum: Int = 512) -> Bool {
        guard let value, !value.isEmpty, value.count <= maximum else { return false }
        return !value.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7f }
    }
    private static func validPath(_ value: String?) -> Bool {
        guard let value, text(value, 4096) else { return false }
        return value == "~" || value.hasPrefix("~/") || value.hasPrefix("/")
    }
    private static func absolute(_ value: String) -> String {
        value == "~"
            ? FileManager.default.homeDirectoryForCurrentUser.path
            : value.hasPrefix("~/")
                ? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(String(value.dropFirst(2)))
                    .path
                : (value as NSString).standardizingPath
    }
    private static func boolean(_ value: String?) -> Bool { value == nil || value == "true" || value == "false" }
    private static func page(_ value: [String: String], _ allowed: [String]) -> Bool {
        fields(value, allowed) && (value["cursor"] == nil || text(value["cursor"], 4096))
            && (value["threadId"] == nil || text(value["threadId"]))
            && (value["limit"] == nil || strictLimit(value["limit"]!))
    }
    private static func strictLimit(_ value: String) -> Bool {
        value == "100" || value.range(of: "^[1-9][0-9]?$", options: .regularExpression) != nil
    }

    private static func identity(_ value: [String: Any]) -> Bool {
        text(value["pluginName"], 255)
            && ((validPath(value["marketplacePath"] as? String) && value["remoteMarketplaceName"] == nil)
                || (text(value["remoteMarketplaceName"], 255) && value["marketplacePath"] == nil))
    }
    private static func parameters(_ value: [String: Any]) -> [String: Any] {
        var params: [String: Any] = ["pluginName": value["pluginName"]!]
        if let path = value["marketplacePath"] as? String { params["marketplacePath"] = absolute(path) }
        if let remote = value["remoteMarketplaceName"] as? String { params["remoteMarketplaceName"] = remote }
        return params
    }
}
