import Foundation

enum StreamingClient {
    static func post(
        endpoint: Endpoint, path: String, body: [String: Any]
    ) -> AsyncThrowingStream<Data, Error> {
        request(endpoint: endpoint, path: path, method: "POST", query: [:], body: body)
    }

    static func get(
        endpoint: Endpoint, path: String, query: [String: String] = [:]
    ) -> AsyncThrowingStream<Data, Error> {
        request(endpoint: endpoint, path: path, method: "GET", query: query, body: nil)
    }

    private static func request(
        endpoint: Endpoint, path: String, method: String, query: [String: String], body: [String: Any]?
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                if let url = HTTPClient.url(endpoint: endpoint, path: path, query: query) {
                    var request = URLRequest(url: url, timeoutInterval: 3600)
                    request.httpMethod = method
                    HTTPClient.sign(&request, endpoint: endpoint)
                    if let body {
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                    }
                    do {
                        let (bytes, response) = try await URLSession.shared.bytes(for: request)
                        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                            throw URLError(
                                .badServerResponse,
                                userInfo: [NSLocalizedDescriptionKey: "http \(http.statusCode)"])
                        }
                        for try await line in bytes.lines {
                            if !line.isEmpty { continuation.yield(Data(line.utf8)) }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                } else {
                    continuation.finish(throwing: URLError(.badURL))
                }
            }
        }
    }
}
