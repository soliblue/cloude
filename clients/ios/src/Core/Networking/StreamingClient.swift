import Foundation

enum StreamingError: Error {
    case preHeaders(Error)
    case body(Error)
}

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
            let task = Task {
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
                            continuation.finish(
                                throwing: StreamingError.preHeaders(
                                    URLError(
                                        .badServerResponse,
                                        userInfo: [NSLocalizedDescriptionKey: "http \(http.statusCode)"])))
                            return
                        }
                        do {
                            var buffer = Data()
                            for try await byte in bytes {
                                if byte == 0x0A {
                                    if !buffer.isEmpty {
                                        continuation.yield(buffer)
                                        buffer = Data()
                                    }
                                } else {
                                    buffer.append(byte)
                                }
                            }
                            if !buffer.isEmpty { continuation.yield(buffer) }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: StreamingError.body(error))
                        }
                    } catch {
                        continuation.finish(throwing: StreamingError.preHeaders(error))
                    }
                } else {
                    continuation.finish(throwing: StreamingError.preHeaders(URLError(.badURL)))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
