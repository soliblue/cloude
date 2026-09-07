import Foundation

@MainActor enum HTTPClient {
    static var responses: [String: (Data, HTTPURLResponse)] = [:]
    static var beforeGet: ((String) async -> Void)?
    static func get(
        endpoint: Endpoint, path: String, query: [String: String] = [:], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        let response = responses[path]
        if let beforeGet { await beforeGet(path) }
        return response
    }
    static func response(_ object: [String: Any]) -> (Data, HTTPURLResponse) {
        (
            try! JSONSerialization.data(withJSONObject: object),
            HTTPURLResponse(
                url: URL(string: "https://test.local")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
    }
}
