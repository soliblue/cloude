import Foundation

public struct UsageStats: Codable {
    public let totalSessions: Int
    public let totalMessages: Int
    public let firstSessionDate: String?
    public let dailyActivity: [DailyActivity]
    public let modelUsage: [String: ModelTokens]
    public let hourCounts: [String: Int]
    public let longestSession: LongestSession?

    public init(totalSessions: Int, totalMessages: Int, firstSessionDate: String?, dailyActivity: [DailyActivity], modelUsage: [String: ModelTokens], hourCounts: [String: Int], longestSession: LongestSession?) {
        self.totalSessions = totalSessions
        self.totalMessages = totalMessages
        self.firstSessionDate = firstSessionDate
        self.dailyActivity = dailyActivity
        self.modelUsage = modelUsage
        self.hourCounts = hourCounts
        self.longestSession = longestSession
    }
}

public struct DailyActivity: Codable {
    public let date: String
    public let messageCount: Int
    public let sessionCount: Int
    public let toolCallCount: Int

    public init(date: String, messageCount: Int, sessionCount: Int, toolCallCount: Int) {
        self.date = date
        self.messageCount = messageCount
        self.sessionCount = sessionCount
        self.toolCallCount = toolCallCount
    }
}

public struct ModelTokens: Codable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadInputTokens: Int
    public let cacheCreationInputTokens: Int

    public init(inputTokens: Int, outputTokens: Int, cacheReadInputTokens: Int, cacheCreationInputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
    }
}

public struct LongestSession: Codable {
    public let messageCount: Int
    public let duration: Int

    public init(messageCount: Int, duration: Int) {
        self.messageCount = messageCount
        self.duration = duration
    }
}
