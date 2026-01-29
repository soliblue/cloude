import Foundation

struct StoredResponse: Codable {
    let sessionId: String
    let text: String
    let completedAt: Date
}

struct ResponseStore {
    private static let maxEntries = 50
    private static let maxAge: TimeInterval = 24 * 60 * 60
    private static let storageKey = "ResponseStore.responses"

    private static var responses: [String: StoredResponse] = {
        load()
    }()

    static func store(sessionId: String, text: String) {
        prune()
        responses[sessionId] = StoredResponse(sessionId: sessionId, text: text, completedAt: Date())
        if responses.count > maxEntries {
            let sorted = responses.values.sorted { $0.completedAt < $1.completedAt }
            for response in sorted.prefix(responses.count - maxEntries) {
                responses.removeValue(forKey: response.sessionId)
            }
        }
        save()
    }

    static func retrieve(sessionId: String) -> StoredResponse? {
        prune()
        return responses[sessionId]
    }

    static func clear(sessionId: String) {
        responses.removeValue(forKey: sessionId)
        save()
    }

    private static func prune() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        let staleKeys = responses.filter { $0.value.completedAt < cutoff }.map { $0.key }
        for key in staleKeys {
            responses.removeValue(forKey: key)
        }
        if !staleKeys.isEmpty {
            save()
        }
    }

    private static func load() -> [String: StoredResponse] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: StoredResponse].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func save() {
        if let data = try? JSONEncoder().encode(responses) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
