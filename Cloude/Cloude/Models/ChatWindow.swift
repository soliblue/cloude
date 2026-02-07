import Foundation

enum WindowType: String, CaseIterable, Codable {
    case chat
    case files
    case gitChanges

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .files: return "folder"
        case .gitChanges: return "arrow.triangle.branch"
        }
    }

    var label: String {
        switch self {
        case .chat: return "Chat"
        case .files: return "Files"
        case .gitChanges: return "Changes"
        }
    }
}

struct ChatWindow: Identifiable, Codable {
    let id: UUID
    var type: WindowType
    var conversationId: UUID?

    init(id: UUID = UUID(), type: WindowType = .chat, conversationId: UUID? = nil) {
        self.id = id
        self.type = type
        self.conversationId = conversationId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(WindowType.self, forKey: .type)
        conversationId = try container.decodeIfPresent(UUID.self, forKey: .conversationId)
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, conversationId
    }
}
