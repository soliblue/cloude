import Foundation

struct MessageHistory {
    private static let key = "messageHistory_v1"
    private static let maxEntries = 500
    private static let maxLength = 100

    static func save(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLength, !trimmed.hasPrefix("/") else { return }
        var history = load()
        history.removeAll { $0.lowercased() == trimmed.lowercased() }
        history.insert(trimmed, at: 0)
        if history.count > maxEntries {
            history = Array(history.prefix(maxEntries))
        }
        UserDefaults.standard.set(history, forKey: key)
    }

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func suggestions(for query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty, !q.hasPrefix("/"), !q.hasPrefix("@") else { return [] }
        return load().filter { $0.lowercased().hasPrefix(q) && $0.lowercased() != q }
    }
}
