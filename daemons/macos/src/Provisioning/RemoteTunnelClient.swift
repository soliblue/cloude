import Foundation

enum RemoteTunnelClient {
    private static let reachabilityAttempts = 30
    private static let reachabilityInterval: Duration = .seconds(2)
    private static let reachabilityTimeout: TimeInterval = 3

    static func putMac(identity: RemoteTunnelIdentity) async -> Bool {
        if let request = request(
            method: "PUT",
            path: "/macs/\(identity.macInstallationId)",
            identity: identity,
            body: RemoteTunnelMacRequest(displayName: DaemonHost.computerName)
        ),
            let (_, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse
        {
            return http.statusCode == 200
        }
        return false
    }

    static func putTunnel(identity: RemoteTunnelIdentity) async -> RemoteTunnelResponse? {
        if let request = request(
            method: "PUT",
            path: "/macs/\(identity.macInstallationId)/tunnel",
            identity: identity
        ),
            let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse,
            http.statusCode == 200
        {
            return try? JSONDecoder().decode(RemoteTunnelResponse.self, from: data)
        }
        return nil
    }

    static func isPublicRouteReady(endpoint: RemoteTunnelEndpoint, authToken: String) async -> Bool {
        var components = URLComponents()
        components.scheme = "https"
        components.host = endpoint.host
        components.port = endpoint.port
        components.path = "/ping"
        if let url = components.url {
            for _ in 0..<reachabilityAttempts {
                var request = URLRequest(url: url, timeoutInterval: reachabilityTimeout)
                request.httpMethod = "GET"
                request.setValue("RemoteCCDaemon/1", forHTTPHeaderField: "User-Agent")
                request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                if let (_, response) = try? await URLSession.shared.data(for: request),
                    let http = response as? HTTPURLResponse,
                    http.statusCode == 200
                {
                    return true
                }
                try? await Task.sleep(for: reachabilityInterval)
            }
        }
        return false
    }

    private static func request<Body: Encodable>(
        method: String,
        path: String,
        identity: RemoteTunnelIdentity,
        body: Body?
    ) -> URLRequest? {
        if var request = request(method: method, path: path, identity: identity) {
            if let body {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try? JSONEncoder().encode(body)
            }
            return request
        }
        return nil
    }

    private static func request(
        method: String,
        path: String,
        identity: RemoteTunnelIdentity
    ) -> URLRequest? {
        if let url = url(path: path) {
            var request = URLRequest(url: url, timeoutInterval: 20)
            request.httpMethod = method
            request.setValue("RemoteCCDaemon/1", forHTTPHeaderField: "User-Agent")
            request.setValue(identity.macSecret, forHTTPHeaderField: "X-Mac-Secret")
            return request
        }
        return nil
    }

    private static func url(path: String) -> URL? {
        if var components = URLComponents(
            url: RemoteTunnelConfiguration.provisioningURL,
            resolvingAgainstBaseURL: false
        ) {
            components.path = path
            return components.url
        }
        return nil
    }
}
