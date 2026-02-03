import Foundation

public enum AgentState: String, Codable {
    case idle
    case running
    case compacting
}

public struct QuestionOption: Codable, Identifiable, Equatable {
    public let id: String
    public let label: String
    public let description: String?

    public init(label: String, description: String? = nil) {
        self.id = UUID().uuidString
        self.label = label
        self.description = description
    }

    public init(id: String, label: String, description: String? = nil) {
        self.id = id
        self.label = label
        self.description = description
    }
}

public struct Question: Codable, Identifiable, Equatable {
    public let id: String
    public let text: String
    public let options: [QuestionOption]
    public let multiSelect: Bool

    public init(text: String, options: [QuestionOption], multiSelect: Bool = false) {
        self.id = UUID().uuidString
        self.text = text
        self.options = options
        self.multiSelect = multiSelect
    }

    public init(id: String, text: String, options: [QuestionOption], multiSelect: Bool = false) {
        self.id = id
        self.text = text
        self.options = options
        self.multiSelect = multiSelect
    }
}

public struct AgentProcessInfo: Codable, Identifiable {
    public let pid: Int32
    public let command: String
    public let startTime: Date?
    public let conversationId: String?
    public let conversationName: String?

    public var id: Int32 { pid }

    public init(pid: Int32, command: String, startTime: Date?, conversationId: String? = nil, conversationName: String? = nil) {
        self.pid = pid
        self.command = command
        self.startTime = startTime
        self.conversationId = conversationId
        self.conversationName = conversationName
    }
}
