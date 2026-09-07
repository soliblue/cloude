import Foundation

@MainActor enum HTTPClient {
    static var status = 200
    static var count = 0
    static var beforeResponse: (() async -> Void)?
    static func post(endpoint: Endpoint, path: String) async -> (Data, HTTPURLResponse)? {
        precondition(path.hasSuffix("/chat/abort"))
        count += 1
        if let beforeResponse { await beforeResponse() }
        return (
            Data("{}".utf8),
            HTTPURLResponse(
                url: URL(string: "https://test.local")!, statusCode: status, httpVersion: nil, headerFields: nil)!
        )
    }
}
