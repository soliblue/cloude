//
//  AuthManager.swift
//  Cloude Agent
//
//  Manages auth token in Keychain
//

import Foundation
import Security

class AuthManager {
    static let shared = AuthManager()

    private let service = "com.cloude.agent"
    private let account = "authToken"

    private init() {}

    var token: String {
        get {
            if let existing = getFromKeychain() {
                return existing
            }
            // Generate new token on first run
            let newToken = generateToken()
            saveToKeychain(newToken)
            return newToken
        }
        set {
            saveToKeychain(newValue)
        }
    }

    func regenerateToken() -> String {
        let newToken = generateToken()
        saveToKeychain(newToken)
        return newToken
    }

    private func generateToken() -> String {
        // Generate a secure random token
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
        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
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
