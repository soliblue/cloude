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
    var fileBrowserRootPath: String?
    var gitRepoRootPath: String?

    init(
        id: UUID = UUID(),
        tab: WindowTab = .chat,
        conversationId: UUID? = nil,
        fileBrowserRootPath: String? = nil,
        gitRepoRootPath: String? = nil
    ) {
        self.id = id
        self.tab = tab
        self.conversationId = conversationId
        self.fileBrowserRootPath = fileBrowserRootPath
        self.gitRepoRootPath = gitRepoRootPath
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
        fileBrowserRootPath = try container.decodeIfPresent(String.self, forKey: .fileBrowserRootPath)
        gitRepoRootPath = try container.decodeIfPresent(String.self, forKey: .gitRepoRootPath)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tab, forKey: .tab)
        try container.encodeIfPresent(conversationId, forKey: .conversationId)
        try container.encodeIfPresent(fileBrowserRootPath, forKey: .fileBrowserRootPath)
        try container.encodeIfPresent(gitRepoRootPath, forKey: .gitRepoRootPath)
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, tab, conversationId, fileBrowserRootPath, gitRepoRootPath
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
