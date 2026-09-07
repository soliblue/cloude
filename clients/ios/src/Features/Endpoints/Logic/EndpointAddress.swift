import Foundation

struct EndpointAddress: Equatable {
    let host: String
    let port: Int
    let scheme: String

    init?(input: String, port: Int = 8765, scheme: String? = nil) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitScheme = trimmed.contains("://")
        let authority =
            !explicitScheme && !trimmed.hasPrefix("[") && trimmed.filter({ $0 == ":" }).count > 1
            ? "[\(trimmed)]" : trimmed
        if let components = URLComponents(
            string: explicitScheme ? trimmed : "\(scheme ?? (port == 443 ? "https" : "http"))://\(authority)"),
            let transport = components.scheme?.lowercased(), ["http", "https"].contains(transport),
            let host = components.host, !host.isEmpty,
            !host.contains(where: { $0.isWhitespace }),
            components.user == nil, components.password == nil,
            components.path.isEmpty || components.path == "/",
            components.query == nil, components.fragment == nil,
            components.url != nil
        {
            self.host = host
            self.port = components.port ?? (explicitScheme ? (transport == "https" ? 443 : 80) : port)
            self.scheme = transport
            if (1...65535).contains(self.port) { return }
        }
        return nil
    }
}
