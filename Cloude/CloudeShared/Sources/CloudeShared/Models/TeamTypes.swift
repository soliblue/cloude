import Foundation

public enum TeammateStatus: String, Codable {
    case spawning
    case working
    case idle
    case shutdown
}

public struct TeammateInfo: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let agentType: String
    public let model: String
    public let color: String
    public var status: TeammateStatus
    public var lastMessage: String?
    public var lastMessageAt: Date?
    public let spawnedAt: Date

    public init(id: String, name: String, agentType: String, model: String, color: String, status: TeammateStatus = .spawning, spawnedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.agentType = agentType
        self.model = model
        self.color = color
        self.status = status
        self.spawnedAt = spawnedAt
    }
}

public struct TeamInboxMessage: Codable, Equatable {
    public let from: String
    public let text: String
    public let summary: String?
    public let timestamp: Date
    public let color: String?

    public init(from: String, text: String, summary: String?, timestamp: Date, color: String?) {
        self.from = from
        self.text = text
        self.summary = summary
        self.timestamp = timestamp
        self.color = color
    }
}
