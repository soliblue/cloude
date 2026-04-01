import Foundation
import CloudeShared

extension ConversationStore {
    func save() {
        for conversation in conversations {
            saveConversation(conversation)
        }
    }

    func saveConversation(_ conversation: Conversation) {
        if let data = try? JSONEncoder().encode(conversation) {
            try? data.write(to: fileURL(for: conversation.id))
        }
    }

    func deleteConversationFile(_ id: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    func fileURL(for id: UUID) -> URL {
        Self.conversationsDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    func load() {
        if let legacy: [Conversation] = UserDefaults.standard.codable([Conversation].self, forKey: legacySaveKey), !legacy.isEmpty {
            conversations = legacy
            for conversation in conversations {
                saveConversation(conversation)
            }
            UserDefaults.standard.removeObject(forKey: legacySaveKey)
        } else {
            let dir = Self.conversationsDirectory
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
                let loaded = files.compactMap { url -> Conversation? in
                    guard url.pathExtension == "json",
                          let data = try? Data(contentsOf: url) else { return nil }
                    return try? JSONDecoder().decode(Conversation.self, from: data)
                }
                await MainActor.run { self?.conversations = loaded }
            }
        }
    }
}
