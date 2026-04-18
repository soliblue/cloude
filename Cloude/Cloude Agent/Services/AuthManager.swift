import Foundation
import Security

class AuthManager {
    static let shared = AuthManager()

    private let service = "com.cloude.agent"
    private let account = "authToken"

    private var failedAttempts: [String: [Date]] = [:]
    private let maxAttempts = 3
    private let lockoutWindow: TimeInterval = 300

    private init() {}

    func isRateLimited(ip: String) -> Bool {
        cleanupOldAttempts(for: ip)
        let attempts = failedAttempts[ip] ?? []
        return attempts.count >= maxAttempts
    }

    func recordFailedAttempt(ip: String) {
        cleanupOldAttempts(for: ip)
        failedAttempts[ip, default: []].append(Date())
    }

    func clearAttempts(for ip: String) {
        failedAttempts.removeValue(forKey: ip)
    }

    private func cleanupOldAttempts(for ip: String) {
        let cutoff = Date().addingTimeInterval(-lockoutWindow)
        failedAttempts[ip] = failedAttempts[ip]?.filter { $0 > cutoff } ?? []
    }

    var token: String {
        get {
            if let existing = getFromKeychain() {
                return existing
            }
            let newToken = generateToken()
            saveToKeychain(newToken)
            return newToken
        }
        set {
            saveToKeychain(newValue)
        }
    }

    private func generateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func getFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    private func saveToKeychain(_ token: String) {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard let data = token.data(using: .utf8) else { return }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
