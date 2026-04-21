import SwiftUI

struct ChatViewMessageListRowToolPillSheetEditDiffRow: View {
    enum Kind { case added, removed }

    let text: String
    let kind: Kind

    var body: some View {
        HStack(alignment: .top, spacing: ThemeTokens.Spacing.s) {
            Text(kind == .added ? "+" : "-")
                .appFont(size: ThemeTokens.Text.m, weight: .semibold, design: .monospaced)
                .foregroundColor(marker)
                .frame(width: ThemeTokens.Spacing.m, alignment: .leading)
            Text(text.isEmpty ? " " : text)
                .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, ThemeTokens.Spacing.xs)
        .padding(.horizontal, ThemeTokens.Spacing.s)
        .background(background)
    }

    private var marker: Color {
        kind == .added ? ThemeColor.success : ThemeColor.danger
    }

    private var background: Color {
        (kind == .added ? ThemeColor.success : ThemeColor.danger).opacity(ThemeTokens.Opacity.s)
    }
}
