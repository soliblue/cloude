import SwiftUI

struct ChatViewMessageListRowToolPillSheetChip: View {
    let icon: String?
    let label: String
    let tint: Color

    init(icon: String? = nil, label: String, tint: Color = .secondary) {
        self.icon = icon
        self.label = label
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .appFont(size: ThemeTokens.Text.s, weight: .semibold)
            }
            Text(label)
                .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, ThemeTokens.Spacing.s)
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .background(tint.opacity(ThemeTokens.Opacity.s))
        .clipShape(Capsule())
    }
}
