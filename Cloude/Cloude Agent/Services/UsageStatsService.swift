import Foundation
import CloudeShared

struct UsageStatsService {
    static func readStats() -> UsageStats {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/stats-cache.json")

        guard let data = try? Data(contentsOf: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return UsageStats(totalSessions: 0, totalMessages: 0, firstSessionDate: nil, dailyActivity: [], modelUsage: [:], hourCounts: [:], longestSession: nil)
        }

        let totalSessions = json["totalSessions"] as? Int ?? 0
        let totalMessages = json["totalMessages"] as? Int ?? 0
        let firstSessionDate = json["firstSessionDate"] as? String

        var dailyActivity: [DailyActivity] = []
        if let days = json["dailyActivity"] as? [[String: Any]] {
            for day in days {
                dailyActivity.append(DailyActivity(
                    date: day["date"] as? String ?? "",
                    messageCount: day["messageCount"] as? Int ?? 0,
                    sessionCount: day["sessionCount"] as? Int ?? 0,
                    toolCallCount: day["toolCallCount"] as? Int ?? 0
                ))
            }
        }

        var modelUsage: [String: ModelTokens] = [:]
        if let models = json["modelUsage"] as? [String: [String: Any]] {
            for (name, tokens) in models {
                modelUsage[name] = ModelTokens(
                    inputTokens: tokens["inputTokens"] as? Int ?? 0,
                    outputTokens: tokens["outputTokens"] as? Int ?? 0,
                    cacheReadInputTokens: tokens["cacheReadInputTokens"] as? Int ?? 0,
                    cacheCreationInputTokens: tokens["cacheCreationInputTokens"] as? Int ?? 0
                )
            }
        }

        var hourCounts: [String: Int] = [:]
        if let hours = json["hourCounts"] as? [String: Int] {
            hourCounts = hours
        }

        var longestSession: LongestSession?
        if let longest = json["longestSession"] as? [String: Any] {
            longestSession = LongestSession(
                messageCount: longest["messageCount"] as? Int ?? 0,
                duration: longest["duration"] as? Int ?? 0
            )
        }

        return UsageStats(
            totalSessions: totalSessions,
            totalMessages: totalMessages,
            firstSessionDate: firstSessionDate,
            dailyActivity: dailyActivity,
            modelUsage: modelUsage,
            hourCounts: hourCounts,
            longestSession: longestSession
        )
    }
}
