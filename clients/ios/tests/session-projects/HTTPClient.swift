import Foundation

@MainActor enum HTTPClient {
    static var response: (Data, HTTPURLResponse)?
    static var beforeResponse: (() async -> Void)?
    static var lastQuery: [String: String] = [:]
    static var lastEndpointId: UUID?
    static func get(
        endpoint: Endpoint, path: String, query: [String: String], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        precondition(path == "/codex/projects")
        lastQuery = query
        lastEndpointId = endpoint.id
        let result = response
        if let beforeResponse { await beforeResponse() }
        return result
    }
}
