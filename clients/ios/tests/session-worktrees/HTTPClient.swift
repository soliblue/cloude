import Foundation

@MainActor enum HTTPClient {
    static var response: (Data, HTTPURLResponse)?
    static var beforeResponse: (() async -> Void)?
    static var body: [String: Any] = [:]
    static var query: [String: String] = [:]
    static var calls = 0
    static func get(
        endpoint: Endpoint, path: String, query: [String: String], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        precondition(path.hasSuffix("/git/branches"))
        self.query = query
        let result = response
        if let beforeResponse { await beforeResponse() }
        return result
    }
    static func post(
        endpoint: Endpoint, path: String, body: [String: Any], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        precondition(path.hasSuffix("/git/worktrees"))
        self.body = body
        calls += 1
        let result = response
        if let beforeResponse { await beforeResponse() }
        return result
    }
    static func set(_ value: [String: Any], status: Int = 200) {
        response = (
            try! JSONSerialization.data(withJSONObject: value),
            HTTPURLResponse(
                url: URL(string: "https://test.local")!, statusCode: status, httpVersion: nil, headerFields: nil)!
        )
    }
}
