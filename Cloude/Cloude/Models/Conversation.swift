import Foundation
import Combine

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
    var costLimitUsd: Double?
    var defaultEffort: EffortLevel?
    var defaultModel: ModelSelection?

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

    init(name: String? = nil, symbol: String? = nil, id: UUID = UUID(), sessionId: String? = nil, workingDirectory: String? = nil, pendingFork: Bool = false) {
        self.id = id
        self.sessionId = sessionId
        self.workingDirectory = workingDirectory
        self.createdAt = Date()
        self.lastMessageAt = Date()
        self.messages = []
        self.pendingMessages = []
        self.pendingFork = pendingFork
        self.costLimitUsd = nil
        self.defaultEffort = nil
        self.defaultModel = nil
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
        costLimitUsd = try container.decodeIfPresent(Double.self, forKey: .costLimitUsd)
        defaultEffort = try container.decodeIfPresent(EffortLevel.self, forKey: .defaultEffort)
        defaultModel = try container.decodeIfPresent(ModelSelection.self, forKey: .defaultModel)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, symbol, sessionId, workingDirectory, createdAt, lastMessageAt, messages, pendingMessages, pendingFork, costLimitUsd, defaultEffort, defaultModel
    }
}

enum ToolCallState: String, Codable {
    case executing
    case complete
}

struct ToolCall: Codable {
    let name: String
    let input: String?
    let toolId: String
    let parentToolId: String?
    var textPosition: Int?
    var state: ToolCallState
    var resultSummary: String?

    init(name: String, input: String?, toolId: String = UUID().uuidString, parentToolId: String? = nil, textPosition: Int? = nil, state: ToolCallState = .complete) {
        self.name = name
        self.input = input
        self.toolId = toolId
        self.parentToolId = parentToolId
        self.textPosition = textPosition
        self.state = state
        self.resultSummary = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        input = try container.decodeIfPresent(String.self, forKey: .input)
        toolId = try container.decode(String.self, forKey: .toolId)
        parentToolId = try container.decodeIfPresent(String.self, forKey: .parentToolId)
        textPosition = try container.decodeIfPresent(Int.self, forKey: .textPosition)
        state = try container.decodeIfPresent(ToolCallState.self, forKey: .state) ?? .complete
        resultSummary = try container.decodeIfPresent(String.self, forKey: .resultSummary)
    }

    private enum CodingKeys: String, CodingKey {
        case name, input, toolId, parentToolId, textPosition, state, resultSummary
    }
}

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let isUser: Bool
    var text: String
    let timestamp: Date
    var toolCalls: [ToolCall]
    var durationMs: Int?
    var costUsd: Double?
    var isQueued: Bool
    var wasInterrupted: Bool
    var imageBase64: String?
    var imageThumbnails: [String]?
    var serverUUID: String?

    init(isUser: Bool, text: String, toolCalls: [ToolCall] = [], durationMs: Int? = nil, costUsd: Double? = nil, isQueued: Bool = false, wasInterrupted: Bool = false, imageBase64: String? = nil, imageThumbnails: [String]? = nil, serverUUID: String? = nil) {
        self.id = UUID()
        self.isUser = isUser
        self.text = text
        self.timestamp = Date()
        self.toolCalls = toolCalls
        self.durationMs = durationMs
        self.costUsd = costUsd
        self.isQueued = isQueued
        self.wasInterrupted = wasInterrupted
        self.imageBase64 = imageBase64
        self.imageThumbnails = imageThumbnails
        self.serverUUID = serverUUID
    }

    init(isUser: Bool, text: String, timestamp: Date, toolCalls: [ToolCall] = [], serverUUID: String? = nil) {
        self.id = UUID()
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
        self.toolCalls = toolCalls
        self.durationMs = nil
        self.costUsd = nil
        self.isQueued = false
        self.wasInterrupted = false
        self.imageBase64 = nil
        self.imageThumbnails = nil
        self.serverUUID = serverUUID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        isUser = try container.decode(Bool.self, forKey: .isUser)
        text = try container.decode(String.self, forKey: .text)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        toolCalls = try container.decodeIfPresent([ToolCall].self, forKey: .toolCalls) ?? []
        durationMs = try container.decodeIfPresent(Int.self, forKey: .durationMs)
        costUsd = try container.decodeIfPresent(Double.self, forKey: .costUsd)
        isQueued = try container.decodeIfPresent(Bool.self, forKey: .isQueued) ?? false
        wasInterrupted = try container.decodeIfPresent(Bool.self, forKey: .wasInterrupted) ?? false
        imageBase64 = try container.decodeIfPresent(String.self, forKey: .imageBase64)
        imageThumbnails = try container.decodeIfPresent([String].self, forKey: .imageThumbnails)
        serverUUID = try container.decodeIfPresent(String.self, forKey: .serverUUID)
    }

    private enum CodingKeys: String, CodingKey {
        case id, isUser, text, timestamp, toolCalls, durationMs, costUsd, isQueued, wasInterrupted, imageBase64, imageThumbnails, serverUUID
    }
}

enum EffortLevel: String, Codable, CaseIterable {
    case low
    case medium
    case high
    case max

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .max: return "Max"
        }
    }
}

enum ModelSelection: String, Codable, CaseIterable {
    case opus = "claude-opus-4-6"
    case sonnet = "claude-sonnet-4-5-20250929"
    case haiku = "claude-haiku-4-5-20251001"

    var displayName: String {
        switch self {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .haiku: return "Haiku"
        }
    }

    var symbolName: String {
        switch self {
        case .opus: return "crown"
        case .sonnet: return "hare"
        case .haiku: return "leaf"
        }
    }
}
