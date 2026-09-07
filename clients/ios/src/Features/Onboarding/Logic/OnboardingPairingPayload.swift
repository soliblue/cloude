import Foundation

struct OnboardingPairingPayload: Equatable {
    var host: String
    var port: Int
    var token: String
    var name: String?
    var scheme: String?

    init(host: String, port: Int = 8765, token: String = "", name: String? = nil, scheme: String? = nil) {
        self.host = host
        self.port = port
        self.token = token
        self.name = name
        self.scheme = scheme
    }

    init?(url: URL) {
        if ["cloude", "afto"].contains(url.scheme ?? ""),
            url.host == "pair",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let items = components.queryItems,
            let host = items.first(where: { $0.name == "host" })?.value, !host.isEmpty,
            let token = items.first(where: { $0.name == "token" })?.value, !token.isEmpty
        {
            let portString = items.first(where: { $0.name == "port" })?.value
            if portString == nil || portString.flatMap(Int.init) != nil,
                let address = EndpointAddress(
                    input: host, port: portString.flatMap(Int.init) ?? 8765,
                    scheme: items.first(where: { $0.name == "scheme" })?.value)
            {
                self.host = address.host
                self.port = address.port
                self.scheme = address.scheme
                self.token = token
                self.name = items.first(where: { $0.name == "name" })?.value
                return
            }
        }
        return nil
    }
}
