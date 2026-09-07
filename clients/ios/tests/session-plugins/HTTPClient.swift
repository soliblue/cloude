import Foundation

@MainActor enum HTTPClient {
    static var getResponses: [String: (Data, HTTPURLResponse)] = [:]
    static var postResponses: [String: (Data, HTTPURLResponse)] = [:]
    static var queries: [[String: String]] = []
    static var bodies: [[String: Any]] = []
    static var beforeGet: (() async -> Void)?
    static var beforePost: (() async -> Void)?
    static func get(
        endpoint: Endpoint, path: String, query: [String: String], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        queries.append(query)
        let response = getResponses[path]
        if let beforeGet { await beforeGet() }
        return response
    }
    static func post(
        endpoint: Endpoint, path: String, body: [String: Any], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        bodies.append(body)
        let response = postResponses[path]
        if let beforePost { await beforePost() }
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
    static func response(_ object: [String: Any], status: Int = 200) -> (Data, HTTPURLResponse) {
        (
            try! JSONSerialization.data(withJSONObject: object),
            HTTPURLResponse(
                url: URL(string: "https://test.local")!, statusCode: status, httpVersion: nil, headerFields: nil)!
        )
    }
}
