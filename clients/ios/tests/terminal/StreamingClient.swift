import Foundation

@MainActor enum StreamingClient {
    static var lines: [Data] = []
    static var queries: [[String: String]] = []
    static func get(endpoint: Endpoint, path: String, query: [String: String]) -> AsyncThrowingStream<Data, Error> {
        queries.append(query)
        return AsyncThrowingStream { continuation in
            for line in lines { continuation.yield(line) }
            continuation.finish()
        }
    }
}
