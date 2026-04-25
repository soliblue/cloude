import SwiftData
import SwiftUI

struct SessionViewTabsChatLabel: View {
    let sessionId: UUID
    let isActive: Bool
    @Environment(\.appAccent) private var appAccent
    @Query private var sessions: [Session]

    init(sessionId: UUID, isActive: Bool) {
        self.sessionId = sessionId
        self.isActive = isActive
        _sessions = Query(
            filter: #Predicate<Session> { $0.id == sessionId }
        )
    }

    var body: some View {
        #if DEBUG
        let _ = Self._logChanges()
        #endif
        let _ = PerfCounters.bump("svt.chat.body")
        let totalCost = sessions.first?.totalCostUsd ?? 0
        HStack(spacing: ThemeTokens.Spacing.xs) {
            if totalCost > 0 {
                Text(Self.formatCost(totalCost))
                    .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    .monospacedDigit()
            } else {
                Image(systemName: SessionTab.chat.symbol)
                    .appFont(size: ThemeTokens.Text.m, weight: .medium)
            }
        }
        .foregroundColor(isActive ? appAccent.color : .secondary)
    }

    static func formatCost(_ value: Double) -> String {
        if value < 10 { return String(format: "$%.2f", value) }
        if value < 100 { return String(format: "$%.1f", value) }
        if value < 1000 { return String(format: "$%.0f", value) }
        if value < 10_000 { return String(format: "$%.1fk", value / 1000) }
        return String(format: "$%.0fk", value / 1000)
    }
}
