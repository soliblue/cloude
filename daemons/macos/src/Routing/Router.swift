import Foundation

enum Router {
    static func handle(_ request: HTTPRequest) -> HTTPResponse {
        if AuthMiddleware.isAuthorized(request) {
            let (path, _) = RouteMatcher.split(request.path)
            if request.method == "GET" {
                if path == "/ping" {
                    return PingHandler.handle(request)
                }
                if let params = RouteMatcher.match(path, pattern: "/sessions/:id/files") {
                    return FilesHandler.list(request, params: params)
                }
                if let params = RouteMatcher.match(path, pattern: "/sessions/:id/files/read") {
                    return FilesHandler.read(request, params: params)
                }
                if let params = RouteMatcher.match(path, pattern: "/sessions/:id/files/search") {
                    return FilesHandler.search(request, params: params)
                }
            }
            return HTTPResponse.json(404, ["error": "not_found"])
        }
        return HTTPResponse.json(401, ["error": "unauthorized"])
    }
}
