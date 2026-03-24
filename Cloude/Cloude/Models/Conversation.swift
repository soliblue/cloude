import Foundation
import CloudeShared

struct Conversation: Codable, Identifiable {
    let id: UUID
    var name: String
    var symbol: String?
    var sessionId: String?
    var workingDirectory: String?
    let createdAt: Date
    var lastMessageAt: Date
    var messages: [ChatMessage]
    var pendingMessages: [ChatMessage]
    var pendingFork: Bool
    var defaultEffort: EffortLevel?
    var defaultModel: ModelSelection?
    var environmentId: UUID?
    var attachedBranch: String?
    var worktreePath: String?
    var originalWorkingDirectory: String?

    var isEmpty: Bool {
        messages.isEmpty && pendingMessages.isEmpty && sessionId == nil
    }

    var totalCost: Double {
        messages.compactMap(\.costUsd).reduce(0, +)
    }

    static let randomNames = [
        "Spark", "Nova", "Pulse", "Echo", "Drift", "Blaze", "Frost", "Dusk",
        "Dawn", "Flux", "Glow", "Haze", "Mist", "Peak", "Reef", "Sage",
        "Tide", "Vale", "Wave", "Zen", "Bolt", "Cove", "Edge", "Fern",
        "Grid", "Hive", "Jade", "Kite", "Leaf", "Maze", "Nest", "Opal",
        "Pine", "Quill", "Rush", "Sand", "Twig", "Vine", "Wisp", "Yarn",
        "Arc", "Bay", "Cliff", "Dell", "Elm", "Fog", "Glen", "Hill",
        "Ivy", "Jet", "Key", "Lane", "Moon", "Nook", "Oak", "Path"
    ]

    static let randomSymbols = [
        "star", "heart", "bolt", "flame", "leaf", "moon", "sun.max", "cloud",
        "sparkles", "wand.and.stars", "lightbulb", "paperplane", "rocket",
        "globe", "map", "flag", "bookmark", "tag", "bubble.left", "terminal",
        "paintbrush", "pencil", "folder", "doc", "book", "briefcase",
        "hammer", "wrench", "gearshape", "cpu", "lock", "key", "eye",
        "hare", "tortoise", "bird", "fish", "tree", "mountain.2", "drop"
    ]

    init(name: String? = nil, symbol: String? = nil, id: UUID = UUID(), sessionId: String? = nil, workingDirectory: String? = nil, pendingFork: Bool = false, environmentId: UUID? = nil) {
        self.id = id
        self.sessionId = sessionId
        self.workingDirectory = workingDirectory
        self.createdAt = Date()
        self.lastMessageAt = Date()
        self.messages = []
        self.pendingMessages = []
        self.pendingFork = pendingFork
        self.defaultEffort = nil
        self.defaultModel = nil
        self.environmentId = environmentId
        self.name = name ?? Self.randomNames.randomElement() ?? "Chat"
        self.symbol = symbol ?? Self.randomSymbols.randomElement()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastMessageAt = try container.decode(Date.self, forKey: .lastMessageAt)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        pendingMessages = try container.decodeIfPresent([ChatMessage].self, forKey: .pendingMessages) ?? []
        pendingFork = try container.decodeIfPresent(Bool.self, forKey: .pendingFork) ?? false
        defaultEffort = try container.decodeIfPresent(EffortLevel.self, forKey: .defaultEffort)
        defaultModel = try container.decodeIfPresent(ModelSelection.self, forKey: .defaultModel)
        environmentId = try container.decodeIfPresent(UUID.self, forKey: .environmentId)
        attachedBranch = try container.decodeIfPresent(String.self, forKey: .attachedBranch)
        worktreePath = try container.decodeIfPresent(String.self, forKey: .worktreePath)
        originalWorkingDirectory = try container.decodeIfPresent(String.self, forKey: .originalWorkingDirectory)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, symbol, sessionId, workingDirectory, createdAt, lastMessageAt, messages, pendingMessages, pendingFork, defaultEffort, defaultModel, environmentId, attachedBranch, worktreePath, originalWorkingDirectory
    }
}
