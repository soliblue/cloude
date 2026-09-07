import Foundation

@MainActor enum HTTPClient {
    static var bodies: [[String: Any]] = []
    static var respond = false
    static func post(endpoint: Endpoint, path: String, body: [String: Any]) async -> (Data, HTTPURLResponse)? {
        bodies.append(body)
        return respond
            ? (
                Data(),
                HTTPURLResponse(
                    url: URL(string: "https://remote.example" + path)!, statusCode: 200, httpVersion: nil,
                    headerFields: nil)!
            ) : nil
    }
}
