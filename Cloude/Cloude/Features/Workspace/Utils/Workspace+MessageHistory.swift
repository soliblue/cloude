import Foundation

struct HistoryEntry: Codable {
    let text: String
    let symbol: String?
}

struct MessageHistory {
    private static let key = "messageHistory_v2"
    private static let maxEntries = 500
    private static let maxLength = 100

    static func save(_ text: String, symbol: String? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLength, !trimmed.hasPrefix("/") else { return }
        var history = load()
        history.removeAll { $0.text.lowercased() == trimmed.lowercased() }
        history.insert(HistoryEntry(text: trimmed, symbol: symbol), at: 0)
        if history.count > maxEntries {
            history = Array(history.prefix(maxEntries))
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [HistoryEntry] {
        if let data = UserDefaults.standard.data(forKey: key),
           let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            return entries
        }
        return []
    }

    static func suggestions(for query: String) -> [HistoryEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty, !q.hasPrefix("/"), !q.hasPrefix("@") else { return [] }
        return load().filter { $0.text.lowercased().hasPrefix(q) && $0.text.lowercased() != q }
    }
}
