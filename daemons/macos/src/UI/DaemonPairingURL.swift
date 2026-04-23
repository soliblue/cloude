import Foundation

enum DaemonPairingURL {
    static func current() -> URL? {
        if let host = DaemonHost.localIPv4 {
            return current(host: host, port: Int(HTTPServer.port))
        }
        return nil
    }

    static func current(endpoint: RemoteTunnelEndpoint) -> URL? {
        current(host: endpoint.host, port: endpoint.port)
    }

    private static func current(host: String, port: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "cloude"
        components.host = "pair"
        components.queryItems = [
            URLQueryItem(name: "host", value: host),
            URLQueryItem(name: "port", value: String(port)),
            URLQueryItem(name: "token", value: DaemonAuth.token),
            URLQueryItem(name: "name", value: DaemonHost.computerName),
        ]
        return components.url
    }
}
