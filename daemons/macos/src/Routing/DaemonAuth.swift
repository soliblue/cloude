import Foundation

enum DaemonAuth {
    static let token: String = {
        if let existing = KeychainStore.read(account: "authToken") {
            return existing
        }
        let generated = KeychainStore.randomBase64(byteCount: 32)
        KeychainStore.set(account: "authToken", value: generated)
        return generated
    }()
}
