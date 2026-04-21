import Foundation

enum HTTPClient {
    static func get(
        endpoint: Endpoint, path: String, query: [String: String] = [:], timeout: TimeInterval = 3
    ) async -> (Data, HTTPURLResponse)? {
        if let url = url(endpoint: endpoint, path: path, query: query) {
            var request = URLRequest(url: url, timeoutInterval: timeout)
            request.httpMethod = "GET"
            sign(&request, endpoint: endpoint)
            return await send(request)
        }
        return nil
    }

    static func download(
        endpoint: Endpoint, path: String, query: [String: String] = [:], range: ClosedRange<Int>? = nil
    ) async -> (Data, HTTPURLResponse)? {
        if let url = url(endpoint: endpoint, path: path, query: query) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            sign(&request, endpoint: endpoint)
            if let range {
                request.setValue("bytes=\(range.lowerBound)-\(range.upperBound)", forHTTPHeaderField: "Range")
            }
            return await send(request)
        }
        return nil
    }

    private static func url(endpoint: Endpoint, path: String, query: [String: String]) -> URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = endpoint.host
        components.port = endpoint.port
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url
    }

    private static func sign(_ request: inout URLRequest, endpoint: Endpoint) {
        if let key = SecureStorage.get(account: endpoint.id.uuidString), !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
    }

    private static func send(_ request: URLRequest) async -> (Data, HTTPURLResponse)? {
        if let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse
        {
            return (data, http)
        }
        return nil
    }
}
