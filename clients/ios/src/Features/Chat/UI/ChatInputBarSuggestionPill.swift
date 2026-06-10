import SwiftUI

struct ChatInputBarSuggestionPill: View {
    let suggestion: ChatInputSuggestion
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.xs) {
            Image(systemName: suggestion.icon)
                .appFont(size: ThemeTokens.Text.s)
            Text(suggestion.title)
                .appFont(size: ThemeTokens.Text.s, weight: .medium)
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, ThemeTokens.Spacing.s)
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var tint: Color {
        switch suggestion.kind {
        case .skill: return .purple
        case .agent: return appAccent.color
        case .file: return .orange
        }
    }
}
