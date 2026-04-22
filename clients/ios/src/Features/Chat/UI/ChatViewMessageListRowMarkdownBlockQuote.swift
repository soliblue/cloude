import SwiftUI

struct ChatViewMessageListRowMarkdownBlockQuote: View {
    let text: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(theme.palette.elevated)
                .frame(width: ThemeTokens.Spacing.xs)
            Text(text)
                .appFont(size: ThemeTokens.Text.m)
                .italic()
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, ThemeTokens.Spacing.m)
                .padding(.vertical, ThemeTokens.Spacing.xs)
        }
    }
}
