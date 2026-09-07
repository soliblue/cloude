import Foundation

@main struct StreamingClientTests {
    static func collect(_ path: String) async throws -> [Data] {
        var lines: [Data] = []
        for try await line in StreamingClient.get(endpoint: Endpoint(), path: path) { lines.append(line) }
        return lines
    }

    static func main() async throws {
        URLProtocol.registerClass(StreamingURLProtocol.self)
        let lines = try await collect("/events")
        precondition(lines.count == 20000)
        precondition(String(data: lines.first!, encoding: .utf8) == "{\"index\":0,\"text\":\"é日本語\"}")
        precondition(String(data: lines.last!, encoding: .utf8) == "{\"index\":19999,\"text\":\"é日本語\"}")
        let denied = await Task { try await collect("/denied") }.result
        if case .failure(let error) = denied, case StreamingError.preHeaders = error {
        } else {
            preconditionFailure("HTTP401 must fail before consuming response body")
        }
        let hold = Task { try await collect("/hold") }
        try await Task.sleep(for: .milliseconds(50))
        hold.cancel()
        _ = await hold.result
        for _ in 0..<100 where !StreamingURLProtocol.canceled.withLock({ $0 }) {
            try await Task.sleep(for: .milliseconds(10))
        }
        precondition(StreamingURLProtocol.canceled.withLock { $0 })
        print(
            "Passed 20,000 transport events, split Unicode bytes, final non-newline record, signed HTTP 401 handling, and cancellation closing URLSession reader"
        )
    }
}
