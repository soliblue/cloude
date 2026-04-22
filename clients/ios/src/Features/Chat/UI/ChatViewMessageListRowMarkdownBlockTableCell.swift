import SwiftUI

struct ChatViewMessageListRowMarkdownBlockTableCell: View {
    let text: String
    let isHeader: Bool

    var body: some View {
        Text(parseInline())
            .appFont(size: ThemeTokens.Text.s, weight: isHeader ? .bold : .regular)
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.s)
    }

    private func parseInline() -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }
        return AttributedString(text)
    }
}
