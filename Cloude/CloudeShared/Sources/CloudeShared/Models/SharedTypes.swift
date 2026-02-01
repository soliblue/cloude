import Foundation

public enum AgentState: String, Codable {
    case idle
    case running
    case compacting
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
