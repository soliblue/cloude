import Foundation

public struct StoredToolCall: Codable {
    public let name: String
    public let input: String?
    public let toolId: String
    public let parentToolId: String?
    public let textPosition: Int?

    public init(name: String, input: String?, toolId: String, parentToolId: String? = nil, textPosition: Int? = nil) {
        self.name = name
        self.input = input
        self.toolId = toolId
        self.parentToolId = parentToolId
        self.textPosition = textPosition
    }
}

public struct HistoryMessage: Codable {
    public let isUser: Bool
    public let text: String
    public let timestamp: Date
    public let toolCalls: [StoredToolCall]
    public let serverUUID: String?
    public let model: String?

    public init(isUser: Bool, text: String, timestamp: Date, toolCalls: [StoredToolCall] = [], serverUUID: String? = nil, model: String? = nil) {
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
        self.toolCalls = toolCalls
        self.serverUUID = serverUUID
        self.model = model
    }
}
