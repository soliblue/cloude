import Foundation

enum DaemonPairingURL {
    static func current() -> URL? {
        if let host = DaemonHost.localIPv4 {
            var components = URLComponents()
            components.scheme = "cloude"
            components.host = "pair"
            components.queryItems = [
                URLQueryItem(name: "host", value: host),
                URLQueryItem(name: "port", value: String(HTTPServer.port)),
                URLQueryItem(name: "token", value: DaemonAuth.token),
                URLQueryItem(name: "name", value: DaemonHost.computerName),
            ]
            return components.url
        }
        return nil
    }
}
