//
//  MarkdownText+Blocks.swift
//  Cloude

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
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct BlockquoteView: View {
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color(.systemGray3))
                .frame(width: 3)
            Text(text)
                .font(.body)
                .italic()
                .foregroundColor(.secondary)
                .padding(.leading, 12)
                .padding(.vertical, 4)
        }
    }
}

struct MarkdownTableView: View {
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            TableCell(text: cell.trimmingCharacters(in: .whitespaces), isHeader: rowIndex == 0)
                                .frame(minWidth: 60, alignment: .leading)
                        }
                    }
                    if rowIndex == 0 {
                        Divider()
                    }
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(6)
    }
}

struct TableCell: View {
    let text: String
    let isHeader: Bool

    var body: some View {
        Text(parseInlineMarkdown())
            .font(isHeader ? .caption.bold() : .caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
