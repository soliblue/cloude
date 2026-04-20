import Foundation

enum WindowTab: String, CaseIterable, Codable {
    case chat
    case files
    case gitChanges

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .files: return "folder"
        case .gitChanges: return "point.3.connected.trianglepath.dotted"
        }
    }
}

struct Window: Identifiable, Codable {
    let id: UUID
    var tab: WindowTab
    var conversationId: UUID?

    init(
        id: UUID = UUID(),
        tab: WindowTab = .chat,
        conversationId: UUID? = nil
    ) {
        self.id = id
        self.tab = tab
        self.conversationId = conversationId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let tab = try container.decodeIfPresent(WindowTab.self, forKey: .tab) {
            self.tab = tab
        } else {
            tab = try container.decode(WindowTab.self, forKey: .type)
        }
        conversationId = try container.decodeIfPresent(UUID.self, forKey: .conversationId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tab, forKey: .tab)
        try container.encodeIfPresent(conversationId, forKey: .conversationId)
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, tab, conversationId
    }

    func conversation(in store: ConversationStore) -> Conversation? {
        conversationId.flatMap { store.conversation(withId: $0) }
    }

    func runtimeEnvironmentId(conversationStore: ConversationStore, environmentStore: EnvironmentStore) -> UUID? {
        if conversationId != nil {
            return conversation(in: conversationStore)?.environmentId
        }
        return environmentStore.activeEnvironmentId
    }
}
