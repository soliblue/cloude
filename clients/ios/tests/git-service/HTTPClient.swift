import Foundation

@MainActor enum HTTPClient {
    static var handler: (String, [String: String]) async -> (Data, HTTPURLResponse)? = { _, _ in nil }
    static func get(
        endpoint: Endpoint, path: String, query: [String: String], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        await handler(path, query)
    }
}
