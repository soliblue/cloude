import SwiftUI

struct CodeBlock: View {
    let code: String
    let language: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(SyntaxHighlighter.highlight(code, language: language))
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Color.oceanSecondary)
        .cornerRadius(8)
    }
}

struct BlockquoteView: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Color(.systemGray3))
                .frame(width: 3)
            Text(text)
                .font(.body)
                .italic()
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 12)
                .padding(.vertical, 4)
        }
    }
}

struct MarkdownTableView: View {
    let rows: [[String]]

    private var columnCount: Int {
        rows.map(\.count).max() ?? 0
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    if rowIndex > 0 {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)
                    }
                    HStack(spacing: 0) {
                        ForEach(0..<columnCount, id: \.self) { colIndex in
                            if colIndex > 0 {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 1)
                            }
                            TableCell(
                                text: colIndex < row.count ? row[colIndex].trimmingCharacters(in: .whitespaces) : "",
                                isHeader: rowIndex == 0
                            )
                            .frame(minWidth: 60, alignment: .leading)
                        }
                    }
                    .background(rowIndex == 0 ? Color.gray.opacity(0.08) : Color.clear)
                }
            }
        }
    }
}

private struct TableCell: View {
    let text: String
    let isHeader: Bool

    var body: some View {
        Text(parseInlineMarkdown())
            .font(isHeader ? .caption.bold() : .caption)
            .textSelection(.enabled)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }

    private func parseInlineMarkdown() -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }
        return AttributedString(text)
    }
}

struct HorizontalRuleView: View {
    var body: some View {
        Divider()
            .padding(.vertical, 8)
    }
}
