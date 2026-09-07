import Foundation

@MainActor enum HTTPClient {
    static var getResponse: (Data, HTTPURLResponse)?
    static var postResponse: (Data, HTTPURLResponse)?
    static var beforeGet: (() async -> Void)?
    static var beforePost: (() async -> Void)?
    static var requests: [(String, String, [String: Any])] = []
    static func get(
        endpoint: Endpoint, path: String, query: [String: String] = [:], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        requests.append(("GET", path, query))
        let result = getResponse
        if let beforeGet { await beforeGet() }
        return result
    }
    static func post(
        endpoint: Endpoint, path: String, body: [String: Any], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        requests.append(("POST", path, body))
        let result = postResponse
        if let beforePost { await beforePost() }
        return result
    }
    static func delete(
        endpoint: Endpoint, path: String, body: [String: Any], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        requests.append(("DELETE", path, body))
        return postResponse
    }
    static func response(_ object: [String: Any], status: Int = 200) -> (Data, HTTPURLResponse) {
        (
            try! JSONSerialization.data(withJSONObject: object),
            HTTPURLResponse(
                url: URL(string: "https://test.local")!, statusCode: status, httpVersion: nil, headerFields: nil)!
        )
    }
}
