import Foundation

enum SecureStorage {
    static var values: [String: String] = [:]
    static func get(account: String) -> String? { values[account] }
    static func set(account: String, value: String) { values[account] = value }
    static func delete(account: String) { values.removeValue(forKey: account) }
}
