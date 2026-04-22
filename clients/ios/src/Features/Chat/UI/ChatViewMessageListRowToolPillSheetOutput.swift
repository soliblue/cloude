import SwiftUI

struct ChatViewMessageListRowToolPillSheetOutput: View {
    let text: String
    let isError: Bool
    @State private var isExpanded: Bool = false
    private let previewLineCount = 15
    @Environment(\.theme) private var theme
    @Environment(\.appAccent) private var appAccent

    var body: some View {
        ChatViewMessageListRowToolPillSheetSection(
            title: isError ? "Error" : "Output", icon: "arrow.left.circle"
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(displayed)
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                    .textSelection(.enabled)
                    .foregroundColor(isError ? ThemeColor.danger : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                        .foregroundColor(appAccent.color)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var lines: [String] { text.components(separatedBy: "\n") }
    private var needsTruncation: Bool { lines.count > previewLineCount }
    private var displayed: String {
        if isExpanded || !needsTruncation { return text }
        return lines.prefix(previewLineCount).joined(separator: "\n")
    }
}
