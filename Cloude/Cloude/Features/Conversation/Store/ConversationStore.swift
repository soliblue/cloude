import Foundation
import Combine
import CloudeShared

@MainActor
class ConversationStore: ObservableObject {
    @Published var conversations: [Conversation] = []
    var pendingHistorySyncMetadata: [UUID: (durationMs: Int?, costUsd: Double?, model: String?)] = [:]

    let legacySaveKey = "saved_conversations_v2"

    static var conversationsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("conversations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var listableConversations: [Conversation] {
        conversations
    }

    func conversation(withId id: UUID) -> Conversation? {
        conversations.first { $0.id == id }
    }

    init() {
        load()
    }
}
