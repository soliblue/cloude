import SwiftUI

struct ChatViewMessageListRowToolPillSheetExpandableText: View {
    let text: String
    let previewLineCount: Int
    let tint: Color
    let isError: Bool

    init(text: String, previewLineCount: Int = 15, tint: Color, isError: Bool = false) {
        self.text = text
        self.previewLineCount = previewLineCount
        self.tint = tint
        self.isError = isError
    }

    @State private var isExpanded = false

    var body: some View {
        let lines = text.components(separatedBy: "\n")
        let needsTruncation = lines.count > previewLineCount
        let displayed =
            isExpanded || !needsTruncation
            ? text : lines.prefix(previewLineCount).joined(separator: "\n")
        VStack(alignment: .leading, spacing: 0) {
            Text(displayed)
                .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                .foregroundColor(isError ? ThemeColor.danger : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            if needsTruncation {
                Divider().padding(.vertical, ThemeTokens.Spacing.xs)
                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    HStack(spacing: ThemeTokens.Spacing.xs) {
                        Text(isExpanded ? "Show less" : "Show all \(lines.count) lines")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .appFont(size: ThemeTokens.Text.s, weight: .semibold)
                    }
                    .foregroundColor(tint)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
