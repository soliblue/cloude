import Foundation

struct TeamSummary: Codable, Equatable {
    let teamName: String
    let members: [Member]

    struct Member: Codable, Equatable, Identifiable {
        let name: String
        let color: String
        let model: String
        let agentType: String

        var id: String { name }
    }
}

struct ChatMessage: Codable, Identifiable {
    var id: UUID
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
    var teamSummary: TeamSummary?
    var model: String?
    var isCollapsed: Bool

    init(isUser: Bool, text: String, toolCalls: [ToolCall] = [], durationMs: Int? = nil, costUsd: Double? = nil, isQueued: Bool = false, wasInterrupted: Bool = false, imageBase64: String? = nil, imageThumbnails: [String]? = nil, serverUUID: String? = nil, teamSummary: TeamSummary? = nil, model: String? = nil) {
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
        self.teamSummary = teamSummary
        self.model = model
        self.isCollapsed = false
    }

    init(isUser: Bool, text: String, timestamp: Date, toolCalls: [ToolCall] = [], serverUUID: String? = nil, model: String? = nil) {
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
        self.teamSummary = nil
        self.model = model
        self.isCollapsed = false
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
        teamSummary = try container.decodeIfPresent(TeamSummary.self, forKey: .teamSummary)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, isUser, text, timestamp, toolCalls, durationMs, costUsd, isQueued, wasInterrupted, imageBase64, imageThumbnails, serverUUID, teamSummary, model, isCollapsed
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
    case opus = "opus"
    case sonnet = "sonnet"
    case haiku = "haiku"

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
