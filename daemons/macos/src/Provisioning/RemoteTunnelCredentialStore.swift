import Foundation

enum RemoteTunnelCredentialStore {
    private enum Account: String {
        case macId = "remoteTunnelMacId"
        case macSecret = "remoteTunnelMacSecret"
        case host = "remoteTunnelHost"
        case token = "remoteTunnelToken"
    }

    static var identity: RemoteTunnelIdentity {
        if let macInstallationId = read(.macId),
            let macSecret = read(.macSecret)
        {
            return RemoteTunnelIdentity(macInstallationId: macInstallationId, macSecret: macSecret)
        }
        let identity = RemoteTunnelIdentity(
            macInstallationId: UUID().uuidString.lowercased(),
            macSecret: KeychainStore.randomHex(byteCount: 32)
        )
        set(.macId, identity.macInstallationId)
        set(.macSecret, identity.macSecret)
        return identity
    }

    static var tunnelHost: String? {
        read(.host)
    }

    static var tunnelToken: String? {
        read(.token)
    }

    static func save(tunnel: RemoteTunnelResponse) {
        set(.host, tunnel.hostname)
        set(.token, tunnel.tunnelToken)
    }

    private static func read(_ account: Account) -> String? {
        KeychainStore.read(account: account.rawValue)
    }

    private static func set(_ account: Account, _ value: String) {
        KeychainStore.set(account: account.rawValue, value: value)
    }
}
