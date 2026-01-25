//
//  MarkdownText.swift
//  Cloude
//
//  Native markdown rendering using AttributedString
//

import SwiftUI

struct MarkdownText: View {
    let text: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: text, options: markdownOptions) {
            Text(attributed)
                .textSelection(.enabled)
        } else {
            Text(text)
                .textSelection(.enabled)
        }
    }

    private var markdownOptions: AttributedString.MarkdownParsingOptions {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        return options
    }
}

struct CodeBlock: View {
    let code: String
    let language: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct RichTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let content):
                    MarkdownText(text: content)
                case .code(let content, let language):
                    CodeBlock(code: content, language: language)
                }
            }
        }
    }

    private func parseBlocks() -> [ContentBlock] {
        var blocks: [ContentBlock] = []

        // Simple code block parsing using string operations
        var remaining = text
        let codeBlockMarker = "```"

        while let startRange = remaining.range(of: codeBlockMarker) {
            // Text before code block
            let before = String(remaining[..<startRange.lowerBound])
            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.text(before))
            }

            // Find end of code block
            let afterStart = remaining[startRange.upperBound...]
            if let endRange = afterStart.range(of: codeBlockMarker) {
                let codeContent = String(afterStart[..<endRange.lowerBound])

                // Extract language from first line
                let lines = codeContent.components(separatedBy: "\n")
                let language = lines.first?.trimmingCharacters(in: .whitespaces)
                let code = lines.dropFirst().joined(separator: "\n")

                blocks.append(.code(code, language?.isEmpty == false ? language : nil))
                remaining = String(afterStart[endRange.upperBound...])
            } else {
                // No closing marker, treat rest as text
                blocks.append(.text(remaining))
                remaining = ""
            }
        }

        // Remaining text
        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.text(remaining))
        }

        return blocks
    }

    private enum ContentBlock {
        case text(String)
        case code(String, String?)
    }
}
