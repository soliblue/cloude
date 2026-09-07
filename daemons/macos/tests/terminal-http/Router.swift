import Foundation

enum Router {
    static func handle(_ request: HTTPRequest) -> HTTPResponse {
        if !AuthMiddleware.isAuthorized(request) { return HTTPResponse.json(401, ["error": "unauthorized"]) }
        if request.path == "/health" {
            return HTTPResponse.json(200, ["ok": true, "active": CodexTerminal.shared.hasActiveWork])
        }
        if request.path == "/shutdown", request.method == "POST" {
            CodexClient.shared.stop()
            return HTTPResponse.json(200, ["ok": true])
        }
        if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/terminals/:terminalId/stream"),
            request.method == "GET"
        {
            return CodexTerminalHandler.stream(request, params: params)
        }
        if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/terminals/:terminalId/input"),
            request.method == "POST"
        {
            return CodexTerminalHandler.input(request, params: params)
        }
        if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/terminals/:terminalId/resize"),
            request.method == "POST"
        {
            return CodexTerminalHandler.resize(request, params: params)
        }
        if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/terminals/:terminalId"),
            request.method == "DELETE"
        {
            return CodexTerminalHandler.terminate(request, params: params)
        }
        if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/terminals") {
            if request.method == "GET" { return CodexTerminalHandler.list(request, params: params) }
            if request.method == "POST" { return CodexTerminalHandler.start(request, params: params) }
        }
        return HTTPResponse.json(404, ["error": "not_found"])
    }
}
