import Foundation

enum Router {
    static func handle(_ request: HTTPRequest) -> HTTPResponse {
        if AuthMiddleware.isAuthorized(request) {
            if request.method == "GET" {
                if request.path == "/ping" {
                    return PingHandler.handle(request)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/files") {
                    return FilesHandler.list(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/files/read") {
                    return FilesHandler.read(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/files/search") {
                    return FilesHandler.search(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/chat/resume") {
                    return ChatHandler.resume(request, params: params)
                }
            }
            if request.method == "POST" {
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/chat") {
                    return ChatHandler.start(request, params: params)
                }
                if let params = RouteMatcher.match(request.path, pattern: "/sessions/:id/chat/abort") {
                    return ChatHandler.abort(request, params: params)
                }
            }
            return HTTPResponse.json(404, ["error": "not_found"])
        }
        return HTTPResponse.json(401, ["error": "unauthorized"])
    }
}
