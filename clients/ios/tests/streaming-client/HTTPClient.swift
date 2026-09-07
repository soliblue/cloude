import Foundation

enum HTTPClient {
    static func url(endpoint: Endpoint, path: String, query: [String: String]) -> URL? {
        URL(string: "aftostream://test" + path)
    }
    static func sign(_ request: inout URLRequest, endpoint: Endpoint) {
        request.setValue("Bearer subscription-fixture", forHTTPHeaderField: "Authorization")
    }
}
