import Foundation

enum HTTPClient {
    static var response: (Data, HTTPURLResponse)?
    static var calls = 0
    static var lastHeaders: [String: String] = [:]
    static var beforeGetResponse: (() async -> Void)?
    static var lastBody: [String: Any] = [:]
    static func post(endpoint: Endpoint, path: String, body: [String: Any]) async -> (Data, HTTPURLResponse)? {
        lastBody = body
        return response
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
    static func get(
        endpoint: Endpoint, path: String, timeout: TimeInterval, headers: [String: String] = [:]
    ) async -> (Data, HTTPURLResponse)? {
        calls += 1
        lastHeaders = headers
        let result = response
        if let beforeGetResponse { await beforeGetResponse() }
        return result
    }
}
