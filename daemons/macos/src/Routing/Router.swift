import Foundation

enum Router {
    static func handle(_ request: HTTPRequest) -> HTTPResponse {
        if AuthMiddleware.isAuthorized(request) {
            switch (request.method, request.path) {
            case ("GET", "/ping"):
                return PingHandler.handle(request)
            default:
                return HTTPResponse.json(404, ["error": "not_found"])
            }
        }
        return HTTPResponse.json(401, ["error": "unauthorized"])
    }
}
