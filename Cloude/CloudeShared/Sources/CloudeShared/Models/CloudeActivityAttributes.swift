#if canImport(ActivityKit) && os(iOS)
import Foundation
import ActivityKit

public struct CloudeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var agentState: AgentState
        public var currentTool: String?
        public var toolDetail: String?
        public var lastUpdated: Date

        public init(agentState: AgentState, currentTool: String? = nil, toolDetail: String? = nil) {
            self.agentState = agentState
            self.currentTool = currentTool
            self.toolDetail = toolDetail
            self.lastUpdated = Date()
        }
    }

    public var conversationId: String
    public var conversationName: String
    public var conversationSymbol: String?

    public init(conversationId: String, conversationName: String, conversationSymbol: String? = nil) {
        self.conversationId = conversationId
        self.conversationName = conversationName
        self.conversationSymbol = conversationSymbol
    }
}
#endif
