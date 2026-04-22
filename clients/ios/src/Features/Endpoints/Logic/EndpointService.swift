import Foundation

enum EndpointService {
    @MainActor
    static func ping(endpoint: Endpoint) async {
        let result = await HTTPClient.get(endpoint: endpoint, path: "/ping")
        endpoint.lastCheckReachable = result?.1.statusCode == 200
        endpoint.lastCheckTimestamp = .now
    }

    static func probe(host: String, port: Int, authKey: String) async -> Bool {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = "/ping"
        guard let url = components.url else { return false }
        var request = URLRequest(url: url, timeoutInterval: 3)
        request.httpMethod = "GET"
        if !authKey.isEmpty {
            request.setValue("Bearer \(authKey)", forHTTPHeaderField: "Authorization")
        }
        let result = try? await URLSession.shared.data(for: request)
        return (result?.1 as? HTTPURLResponse)?.statusCode == 200
    }
}
