import Foundation

struct OnboardingPairingPayload: Equatable {
    var host: String
    var port: Int
    var token: String
    var name: String?

    init(host: String, port: Int = 8765, token: String = "", name: String? = nil) {
        self.host = host
        self.port = port
        self.token = token
        self.name = name
    }

    init?(url: URL) {
        if url.scheme == "cloude",
            url.host == "pair",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let items = components.queryItems,
            let host = items.first(where: { $0.name == "host" })?.value, !host.isEmpty,
            let token = items.first(where: { $0.name == "token" })?.value, !token.isEmpty
        {
            let portString = items.first(where: { $0.name == "port" })?.value
            self.host = host
            self.port = portString.flatMap(Int.init) ?? 8765
            self.token = token
            self.name = items.first(where: { $0.name == "name" })?.value
            return
        }
        return nil
    }
}
