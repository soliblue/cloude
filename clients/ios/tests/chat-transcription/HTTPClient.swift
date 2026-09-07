import Foundation

@MainActor enum HTTPClient {
    static var calls = 0
    static var lastEndpoint: UUID?
    static var path = ""
    static var body: [String: Any] = [:]
    static var result: (Data, HTTPURLResponse)?
    static func post(
        endpoint: Endpoint, path: String, body: [String: Any], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        calls += 1
        lastEndpoint = endpoint.id
        Self.path = path
        Self.body = body
        precondition(timeout == 60)
        return result
    }
}
