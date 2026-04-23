import Foundation

enum EndpointService {
    @MainActor
    static func ping(endpoint: Endpoint) async {
        let result = await HTTPClient.get(endpoint: endpoint, path: "/ping")
        endpoint.lastCheckReachable = result?.1.statusCode == 200
        endpoint.lastCheckTimestamp = .now
    }

    static func probe(
        host: String, port: Int, authKey: String, retryWindow: TimeInterval = 0
    ) async -> EndpointProbeResult {
        var components = URLComponents()
        components.scheme = port == 443 ? "https" : "http"
        components.host = host
        components.port = port
        components.path = "/ping"
        if let url = components.url {
            let deadline = Date.now.addingTimeInterval(retryWindow)
            while true {
                let remaining = max(0, deadline.timeIntervalSinceNow)
                let timeout = retryWindow > 0 ? min(1.5, max(0.5, remaining)) : 3
                var request = URLRequest(url: url, timeoutInterval: timeout)
                request.httpMethod = "GET"
                if !authKey.isEmpty {
                    request.setValue("Bearer \(authKey)", forHTTPHeaderField: "Authorization")
                }
                if let (_, response) = try? await URLSession.shared.data(for: request),
                    let http = response as? HTTPURLResponse
                {
                    if http.statusCode == 200 { return .reachable }
                    if http.statusCode == 401 { return .unauthorized }
                    return .invalid
                }
                if retryWindow <= 0 || Date.now >= deadline { return .unreachable }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        return .invalid
    }
}
