import Foundation

@main struct HTTPClientTests {
    @MainActor static func main() async throws {
        URLProtocol.registerClass(HTTPClientURLProtocol.self)
        let endpoint = Endpoint(host: "afto-http.invalid", port: 443)
        let held = Task { await HTTPClient.get(endpoint: endpoint, path: "/hold") }
        for _ in 0..<100 where HTTPClientURLProtocol.pending.withLock({ $0 == nil }) {
            try await Task.sleep(for: .milliseconds(10))
        }
        precondition(HTTPClientURLProtocol.pending.withLock { $0 != nil })
        HTTPClient.invalidate(endpointId: endpoint.id)
        HTTPClientURLProtocol.pending.withLock { $0 }?.finish()
        let stale = await held.value
        precondition(stale == nil)
        precondition(endpoint.capabilities == nil && DaemonVersionObserver.shared.observed.isEmpty)
        let fresh = await HTTPClient.get(endpoint: endpoint, path: "/fresh", query: ["path": "space & é"])
        precondition(fresh?.1.statusCode == 200)
        precondition(endpoint.capabilities == ["codex", "gitWorktrees"])
        precondition(DaemonVersionObserver.shared.observed == [endpoint.id])
        let components = URLComponents(
            url: HTTPClient.url(endpoint: endpoint, path: "/file", query: ["path": "space & é"])!,
            resolvingAgainstBaseURL: false)
        precondition(components?.queryItems?.first?.value == "space & é")
        HTTPClientURLProtocol.pending.withLock { $0 = nil }
        let canceled = Task { await HTTPClient.get(endpoint: endpoint, path: "/hold") }
        for _ in 0..<100 where HTTPClientURLProtocol.pending.withLock({ $0 == nil }) {
            try await Task.sleep(for: .milliseconds(10))
        }
        precondition(HTTPClientURLProtocol.pending.withLock { $0 != nil })
        canceled.cancel()
        let canceledResult = await canceled.value
        precondition(canceledResult == nil && DaemonVersionObserver.shared.observed.count == 1)
        let removed = await HTTPClient.delete(endpoint: endpoint, path: "/delete", body: ["pluginId": "fixture"])
        precondition(removed?.1.statusCode == 200)
        print(
            "HTTP transport: signed requests, invalidated endpoint response suppression, capability updates, encoded paths and cancellation passed"
        )
    }
}
