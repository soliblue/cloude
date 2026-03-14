import SwiftUI
import UIKit

struct CodeBlock: View {
    let code: String
    let language: String?
    @AppStorage("wrapCodeLines") private var defaultWrap = true
    @AppStorage("showCodeLineNumbers") private var defaultLineNumbers = true
    @State private var wrapOverride: Bool?
    @State private var lineNumbersOverride: Bool?
    @State private var copied = false

    private var wrap: Bool { wrapOverride ?? defaultWrap }
    private var lineNumbers: Bool { lineNumbersOverride ?? defaultLineNumbers }
    private var lines: [String] { code.components(separatedBy: "\n") }
    private var isSingleLine: Bool { lines.count == 1 }

    var body: some View {
        VStack(spacing: 0) {
            if !isSingleLine {
                toolbar
                Divider().overlay(Color.gray.opacity(0.3))
            }

            codeContent
        }
        .background(Color.oceanSecondary)
        .cornerRadius(6)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            if let lang = language, !lang.isEmpty {
                Text(lang)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { lineNumbersOverride = !lineNumbers } label: {
                Image(systemName: lineNumbers ? "list.number" : "list.bullet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            Divider().frame(height: 14)
            Button { wrapOverride = !wrap } label: {
                Image(systemName: wrap ? "text.word.spacing" : "arrow.left.and.right.text.vertical")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            Divider().frame(height: 14)
            Button {
                UIPasteboard.general.string = code
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(copied ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var codeContent: some View {
        if wrap {
            HStack(alignment: .top, spacing: 0) {
                if lineNumbers && !isSingleLine {
                    lineNumberColumn
                }
                Text(SyntaxHighlighter.highlight(code, language: language))
                    .font(.system(.caption, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    if lineNumbers && !isSingleLine {
                        lineNumberColumn
                    }
                    Text(SyntaxHighlighter.highlight(code, language: language))
                        .font(.system(.caption, design: .monospaced))
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(12)
                }
            }
        }
    }

    private var lineNumberColumn: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                Text("\(index + 1)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .frame(height: lineHeight)
            }
        }
        .padding(.leading, 12)
        .padding(.vertical, 12)
        .padding(.trailing, 4)
        .background(Color.oceanSecondary)
    }

    private var lineHeight: CGFloat {
        UIFont.monospacedSystemFont(ofSize: UIFont.smallSystemFontSize, weight: .regular).lineHeight
    }
}

struct BlockquoteView: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Color.oceanSurface)
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
                            .frame(minWidth: 60)
                            .background(rowIndex == 0 ? Color.gray.opacity(0.08) : Color.clear)
                            .overlay(alignment: .leading) {
                                if colIndex > 0 {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 1)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
        .scrollClipDisabled()
    }
}

private struct TableCell: View {
    let text: String
    let isHeader: Bool

    var body: some View {
        Text(parseInlineMarkdown())
            .font(isHeader ? .caption.bold() : .caption)
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
