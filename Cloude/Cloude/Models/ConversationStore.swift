import Foundation
import Combine
import CloudeShared

@MainActor
class ConversationStore: ObservableObject {
    @Published var conversations: [Conversation] = []

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

    var conversationsByDirectory: [(directory: String, conversations: [Conversation])] {
        let grouped = Dictionary(grouping: listableConversations) { conv in
            conv.workingDirectory ?? ""
        }
        return grouped.map { dir, convs in
            (directory: dir, conversations: convs.sorted { $0.lastMessageAt > $1.lastMessageAt })
        }.sorted { lhs, rhs in
            let lhsDate = lhs.conversations.first?.lastMessageAt ?? .distantPast
            let rhsDate = rhs.conversations.first?.lastMessageAt ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    var uniqueWorkingDirectories: [String] {
        Array(Set(listableConversations.compactMap { $0.workingDirectory })).filter { !$0.isEmpty }
    }

    init() {
        load()
    }
}
