import Foundation

@MainActor enum HTTPClient {
    static var response: (Data, HTTPURLResponse)?
    static var beforeGet: (() async -> Void)?
    static var beforePost: (() async -> Void)?
    static var body: [String: Any] = [:]
    static var posts = 0
    static func get(endpoint: Endpoint, path: String, timeout: TimeInterval) async -> (Data, HTTPURLResponse)? {
        precondition(path == "/codex/login")
        let result = response
        if let beforeGet { await beforeGet() }
        return result
    }
    static func post(
        endpoint: Endpoint, path: String, body: [String: Any], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        precondition(path == "/codex/login")
        self.body = body
        posts += 1
        let result = response
        if let beforePost { await beforePost() }
        return result
    }
    static func delete(
        endpoint: Endpoint, path: String, body: [String: Any] = [:], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        var request = URLRequest(url: url(endpoint: endpoint, path: path, query: [:])!, timeoutInterval: timeout)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        sign(&request, endpoint: endpoint)
        if let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse
        {
            return (data, http)
        }
        return nil
    }
    static func url(endpoint: Endpoint, path: String, query: [String: String]) -> URL? {
        URL(string: "aftotest://endpoint" + path)
    }
    static func sign(_ request: inout URLRequest, endpoint: Endpoint) {
        request.setValue("Bearer test", forHTTPHeaderField: "Authorization")
    }
    static func set(_ value: [String: Any], status: Int = 200) {
        response = (
            try! JSONSerialization.data(withJSONObject: value),
            HTTPURLResponse(
                url: URL(string: "https://test.local")!, statusCode: status, httpVersion: nil, headerFields: nil)!
        )
    }
}
