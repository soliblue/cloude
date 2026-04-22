import SwiftData
import SwiftUI

struct SessionViewTabsChatLabel: View {
    let session: Session
    let isActive: Bool
    @Environment(\.appAccent) private var appAccent
    @Query private var messages: [ChatMessage]

    init(session: Session, isActive: Bool) {
        self.session = session
        self.isActive = isActive
        let sessionId = session.id
        _messages = Query(
            filter: #Predicate<ChatMessage> { $0.sessionId == sessionId }
        )
    }

    var body: some View {
        let total = messages.compactMap(\.costUsd).reduce(0, +)
        HStack(spacing: ThemeTokens.Spacing.xs) {
            if total > 0 {
                Text(Self.formatCost(total))
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
