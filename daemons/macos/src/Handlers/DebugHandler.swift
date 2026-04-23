import Foundation

enum DebugHandler {
    static func uploadIOSLog(_ request: HTTPRequest) -> HTTPResponse {
        let url = destinationURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let object = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
            let content = object["content"] as? String
        {
            try? Data(content.utf8).write(to: url, options: .atomic)
            return HTTPResponse.json(200, ["ok": true, "path": url.path])
        }
        return HTTPResponse.json(400, ["error": "bad_request"])
    }

    static var destinationURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cloude")
            .appendingPathComponent("ios-logs")
            .appendingPathComponent("latest.log")
    }
}
