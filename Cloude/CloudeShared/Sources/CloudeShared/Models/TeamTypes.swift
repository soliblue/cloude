import Foundation

public enum TeammateStatus: String, Codable {
    case spawning
    case working
    case idle
    case shutdown
}

public struct TeammateMessage: Identifiable, Equatable {
    public let id: UUID
    public let text: String
    public let timestamp: Date

    public init(text: String, timestamp: Date) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
    }
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
    public var messageHistory: [TeammateMessage] = []
    public var unreadCount: Int = 0

    private enum CodingKeys: String, CodingKey {
        case id, name, agentType, model, color, status, lastMessage, lastMessageAt, spawnedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        agentType = try c.decode(String.self, forKey: .agentType)
        model = try c.decode(String.self, forKey: .model)
        color = try c.decode(String.self, forKey: .color)
        status = try c.decode(TeammateStatus.self, forKey: .status)
        lastMessage = try c.decodeIfPresent(String.self, forKey: .lastMessage)
        lastMessageAt = try c.decodeIfPresent(Date.self, forKey: .lastMessageAt)
        spawnedAt = try c.decode(Date.self, forKey: .spawnedAt)
        messageHistory = []
        unreadCount = 0
    }

    public init(id: String, name: String, agentType: String, model: String, color: String, status: TeammateStatus = .spawning, spawnedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.agentType = agentType
        self.model = model
        self.color = color
        self.status = status
        self.spawnedAt = spawnedAt
    }

    public mutating func appendMessage(_ text: String, at timestamp: Date) {
        messageHistory.append(TeammateMessage(text: text, timestamp: timestamp))
        if messageHistory.count > 50 { messageHistory.removeFirst() }
        unreadCount += 1
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
