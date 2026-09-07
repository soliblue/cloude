import Foundation

@main
struct CodexPluginHandlerTests {
    static func request(_ method: String = "GET", body: Any = [:], query: [String: String] = [:]) -> HTTPRequest {
        HTTPRequest(
            head: HTTPRequest.ParsedHead(
                method: method, path: "/fixture", query: query, headers: [:], headerEnd: 0, contentLength: 0),
            body: (try? JSONSerialization.data(withJSONObject: body)) ?? Data())
    }

    static func json(_ response: HTTPResponse) -> [String: Any] {
        if case .buffered(let data) = response.body {
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        }
        return [:]
    }

    static func main() {
        var calls: [(String, [String: Any])] = []
        CodexPluginHandler.transport = { method, params, callback in
            calls.append((method, params))
            callback(.success(["ok": true]))
        }
        precondition(CodexPluginHandler.plugins(request()).status == 200)
        precondition(calls.last?.0 == "plugin/list")
        precondition(calls.last?.1["forceRefetch"] as? Bool == false)
        precondition(CodexPluginHandler.plugins(request(query: ["installed": "true"])).status == 200)
        precondition(calls.last?.0 == "plugin/installed")
        precondition(calls.last?.1["cwds"] as? [String] == [])
        precondition(
            CodexPluginHandler.plugins(request(query: ["installed": "true", "path": "~/project"])).status == 200)
        precondition((calls.last?.1["cwds"] as? [String])?.first?.hasSuffix("/project") == true)
        precondition(
            CodexPluginHandler.plugins(request(query: ["installed": "true", "forceRefetch": "true"])).status == 400)
        precondition(
            CodexPluginHandler.plugin(
                request(
                    "POST",
                    body: ["pluginName": "browser", "remoteMarketplaceName": "official", "installAttemptId": "attempt"])
            ).status == 200)
        precondition(calls.last?.0 == "plugin/install")
        precondition(
            CodexPluginHandler.plugin(
                request(
                    "POST", body: ["pluginName": "browser", "remoteMarketplaceName": "official", "apiKey": "secret"])
            ).status == 400)
        precondition(
            CodexPluginHandler.plugin(
                request("GET", query: ["pluginName": "browser", "remoteMarketplaceName": "official"])
            ).status == 200)
        precondition(calls.last?.0 == "plugin/read")
        precondition(CodexPluginHandler.plugin(request("DELETE", body: ["pluginId": "browser"])).status == 200)
        precondition(calls.last?.0 == "plugin/uninstall")
        precondition(CodexPluginHandler.apps(request()).status == 200)
        precondition(CodexPluginHandler.apps(request(query: ["installed": "nonsense"])).status == 400)
        precondition(CodexPluginHandler.apps(request(query: ["limit": "+1"])).status == 400)
        precondition(CodexPluginHandler.apps(request(query: ["limit": "01"])).status == 400)
        precondition(calls.last?.0 == "app/list")
        precondition(calls.last?.1["limit"] as? Int == 50)
        precondition(
            CodexPluginHandler.apps(request(query: ["installed": "true", "threadId": "thread-1"])).status == 200)
        precondition(calls.last?.0 == "app/installed")
        precondition(calls.last?.1["threadId"] as? String == "thread-1")
        precondition(
            CodexPluginHandler.apps(request(query: ["cursor": "cursor-1", "limit": "7", "threadId": "thread-1"])).status
                == 200)
        precondition(calls.last?.1["cursor"] as? String == "cursor-1")
        precondition(calls.last?.1["limit"] as? Int == 7)
        precondition(calls.last?.1["threadId"] as? String == "thread-1")
        precondition(
            CodexPluginHandler.readApps(
                request("POST", body: ["appIds": ["github", "github", "slack"], "includeTools": true])
            ).status == 200)
        precondition(calls.last?.0 == "app/read")
        precondition(calls.last?.1["appIds"] as? [String] == ["github", "slack"])
        precondition(CodexPluginHandler.mcp(request()).status == 200)
        precondition(CodexPluginHandler.mcp(request(query: ["limit": "01"])).status == 400)
        precondition(calls.last?.0 == "mcpServerStatus/list")
        var recoveryMethods: [String] = []
        var firstList = true
        CodexPluginHandler.transport = { method, _, callback in
            recoveryMethods.append(method)
            if method == "app/list" && firstList {
                firstList = false
                callback(
                    .failure(
                        NSError(
                            domain: "Codex", code: 404,
                            userInfo: [NSLocalizedDescriptionKey: "thread not found: thread-recover"])))
            } else {
                callback(.success(["ok": true]))
            }
        }
        precondition(CodexPluginHandler.apps(request(query: ["threadId": "thread-recover"])).status == 200)
        precondition(recoveryMethods == ["app/list", "thread/read", "thread/resume", "app/list"])
        CodexPluginHandler.transport = { _, _, callback in
            callback(
                .failure(NSError(domain: "fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "private token"])))
        }
        let failure = CodexPluginHandler.plugins(request())
        precondition(failure.status == 502)
        precondition(json(failure)["error"] as? String == "codex_request_failed")
        precondition(json(failure)["message"] == nil)
        print("Codex plugin handlers: strict validation, routing contracts, deduplication and safe RPC failures passed")
    }
}
