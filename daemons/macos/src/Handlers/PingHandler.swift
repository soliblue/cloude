import Foundation

enum PingHandler {
    static func handle(_: HTTPRequest) -> HTTPResponse {
        HTTPResponse.json(200, [
            "ok": true,
            "serverAt": Int(Date().timeIntervalSince1970 * 1000)
        ])
    }
}
