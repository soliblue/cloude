//
//  MarkdownText.swift
//  Cloude
//

import SwiftUI

struct MarkdownText: View {
    let text: String

    var body: some View {
        Text(parseMarkdown())
            .textSelection(.enabled)
    }

    private func parseMarkdown() -> AttributedString {
        var result = AttributedString()
        let lines = text.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let parsedLine = parseLine(line)
            result.append(parsedLine)
            if index < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }

        return result
    }

    private func parseLine(_ line: String) -> AttributedString {
        if line.hasPrefix("### ") {
            var attr = AttributedString(String(line.dropFirst(4)))
            attr.font = .headline
            return attr
        } else if line.hasPrefix("## ") {
            var attr = AttributedString(String(line.dropFirst(3)))
            attr.font = .title3.bold()
            return attr
        } else if line.hasPrefix("# ") {
            var attr = AttributedString(String(line.dropFirst(2)))
            attr.font = .title2.bold()
            return attr
        }

        if let attributed = try? AttributedString(
            markdown: line,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }

        return AttributedString(line)
    }
}

struct RichTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(MarkdownParser.parseBlocks(text).enumerated()), id: \.offset) { _, block in
                ContentBlockView(block: block)
            }
        }
    }
}
