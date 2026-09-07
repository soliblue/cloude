import Foundation

enum HTTPClient {
    static var calls: [(String, [String: String])] = []
    static var responses: [[String: Any]?] = []
    static var beforeGet: ((Int) async -> Void)?

    static func get(
        endpoint: Endpoint, path: String, query: [String: String] = [:], timeout: TimeInterval = 10
    ) async -> (Data, HTTPURLResponse)? {
        calls.append((path, query))
        let index = calls.count - 1
        let result = responses.removeFirst()
        if let beforeGet { await beforeGet(index) }
        endpoint.capabilities = ["codexHistoryPages", "testResponseCapability"]
        if let result {
            return (
                try! JSONSerialization.data(withJSONObject: result),
                HTTPURLResponse(
                    url: URL(string: "http://fixture.invalid")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }
        return nil
    }
}
