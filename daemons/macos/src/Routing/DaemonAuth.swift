import Foundation
import Security

enum DaemonAuth {
    static let token: String = {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "soli.Cloude.agent",
            kSecAttrAccount as String: "authToken"
        ]
        var readQuery = query
        readQuery[kSecReturnData as String] = true
        readQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        if SecItemCopyMatching(readQuery as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let existing = String(data: data, encoding: .utf8) {
            return existing
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let generated = Data(bytes).base64EncodedString()
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(generated.utf8)
        SecItemAdd(add as CFDictionary, nil)
        return generated
    }()
}
