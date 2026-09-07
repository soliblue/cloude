import Foundation

nonisolated struct ChatGoal: Codable {
    let objective: String
    let status: String
    let tokenBudget: Int?
    let tokensUsed: Int
    let timeUsedSeconds: Int

    var statusLabel: String {
        switch status {
        case "usageLimited": "Usage limit reached"
        case "budgetLimited": "Token budget reached"
        default: status.capitalized
        }
    }
}
