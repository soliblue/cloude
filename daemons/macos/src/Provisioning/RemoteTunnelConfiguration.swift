import Foundation

enum RemoteTunnelConfiguration {
    static var provisioningURL: URL {
        let value = ProcessInfo.processInfo.environment["REMOTECC_PROVISIONING_URL"] ?? ""
        if !value.isEmpty, let url = URL(string: value) {
            return url
        }
        return URL(string: "https://remotecc.soli.blue")!
    }
}
