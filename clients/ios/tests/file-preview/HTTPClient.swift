import Foundation

enum HTTPClient {
    static var response: (URL, HTTPURLResponse)?
    static var beforeDownload: (() async -> Void)?

    static func downloadFile(endpoint: Endpoint, path: String, query: [String: String]) async -> (URL, HTTPURLResponse)?
    {
        if let beforeDownload { await beforeDownload() }
        return response
    }
}
