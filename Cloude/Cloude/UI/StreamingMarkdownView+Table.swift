// StreamingMarkdownView+Table.swift

import SwiftUI

struct MarkdownTableView: View {
    let rows: [[String]]

    private var columnCount: Int {
        rows.map(\.count).max() ?? 0
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    if rowIndex > 0 {
                        Divider()
                    }
                    GridRow {
                        ForEach(0..<columnCount, id: \.self) { colIndex in
                            TableCell(
                                text: colIndex < row.count ? row[colIndex].trimmingCharacters(in: .whitespaces) : "",
                                isHeader: rowIndex == 0
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minWidth: DS.Size.xl)
                            .background(rowIndex == 0 ? Color.gray.opacity(DS.Opacity.faint) : Color.clear)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.l)
        }
        .padding(.horizontal, -DS.Spacing.l)
        .scrollClipDisabled()
    }
}

private struct TableCell: View {
    let text: String
    let isHeader: Bool

    var body: some View {
        Text(parseInlineMarkdown())
            .font(.system(size: DS.Text.s, weight: isHeader ? .bold : .regular))
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, DS.Spacing.s)
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
