import Foundation

@MainActor enum HTTPClient {
    static var getResponse: (Data, HTTPURLResponse)?
    static var postResponse: (Data, HTTPURLResponse)?
    static var beforeGet: (() async -> Void)?
    static var beforePost: (() async -> Void)?
    static var getCount = 0
    static var postCount = 0
    static var lastBody: [String: Any] = [:]
    static func get(endpoint: Endpoint, path: String) async -> (Data, HTTPURLResponse)? {
        precondition(path.hasSuffix("/chat/requests"))
        getCount += 1
        let result = getResponse
        if let beforeGet { await beforeGet() }
        return result
    }
    static func post(endpoint: Endpoint, path: String, body: [String: Any]) async -> (Data, HTTPURLResponse)? {
        precondition(path.hasSuffix("/chat/respond"))
        postCount += 1
        lastBody = body
        let result = postResponse
        if let beforePost { await beforePost() }
        return result
    }
    static func response(
        _ requests: [[String: Any]], status: Int = 200, agentAttention: [[String: String]] = []
    ) -> (Data, HTTPURLResponse) {
        (
            try! JSONSerialization.data(withJSONObject: ["requests": requests, "agentAttention": agentAttention]),
            HTTPURLResponse(
                url: URL(string: "https://test.local")!, statusCode: status, httpVersion: nil, headerFields: nil)!
        )
    }
}
