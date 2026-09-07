import Foundation

nonisolated struct ChatUsageWindow: Identifiable {
    let id: String
    let title: String
    let usedPercent: Double
    let resetsAt: Date?
    var remainingPercent: Double { min(100, max(0, 100 - usedPercent)) }
}
