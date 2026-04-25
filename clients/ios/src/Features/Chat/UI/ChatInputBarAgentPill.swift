import SwiftUI

struct ChatInputBarAgentPill: View {
    let name: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ThemeTokens.Spacing.xs) {
                Image(systemName: "person.fill")
                    .appFont(size: ThemeTokens.Text.s)
                Text("@" + name)
                    .appFont(size: ThemeTokens.Text.s)
                    .lineLimit(1)
            }
            .foregroundColor(ThemeColor.orange)
            .padding(.horizontal, ThemeTokens.Spacing.s)
            .padding(.vertical, ThemeTokens.Spacing.xs)
            .background(ThemeColor.orange.opacity(0.15), in: Capsule())
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
