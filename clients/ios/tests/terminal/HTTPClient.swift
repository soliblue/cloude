import Foundation

@MainActor enum HTTPClient {
    static var response: (Data, HTTPURLResponse)?
    static var postBodies: [[String: Any]] = []
    static var beforeResponse: (() -> Void)?
    static var deletes = 0
    static func get(endpoint: Endpoint, path: String, timeout: TimeInterval) async -> (Data, HTTPURLResponse)? {
        beforeResponse?()
        return response
    }
    static func post(
        endpoint: Endpoint, path: String, body: [String: Any], timeout: TimeInterval = 10
    ) async -> (Data, HTTPURLResponse)? {
        postBodies.append(body)
        beforeResponse?()
        return response
    }
    static func delete(endpoint: Endpoint, path: String, timeout: TimeInterval) async -> (Data, HTTPURLResponse)? {
        deletes += 1
        beforeResponse?()
        return response
    }
}
