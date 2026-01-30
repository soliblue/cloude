//
//  RichTextView+Parsing.swift
//  Cloude
//

import Foundation

enum ContentBlock {
    case text(String)
    case code(String, String?)
    case table([[String]])
    case blockquote(String)
    case section(title: String, level: Int, content: [ContentBlock])
    case horizontalRule
}

struct MarkdownParser {
    static func parseBlocks(_ text: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        var remaining = text
        let codeBlockMarker = "```"

        while let startRange = remaining.range(of: codeBlockMarker) {
            let before = String(remaining[..<startRange.lowerBound])
            if !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(contentsOf: parseTextAndTables(before))
            }

            let afterStart = remaining[startRange.upperBound...]
            if let endRange = afterStart.range(of: codeBlockMarker) {
                let codeContent = String(afterStart[..<endRange.lowerBound])
                let lines = codeContent.components(separatedBy: "\n")
                let language = lines.first?.trimmingCharacters(in: .whitespaces)
                let code = lines.dropFirst().joined(separator: "\n")
                blocks.append(.code(code, language?.isEmpty == false ? language : nil))
                remaining = String(afterStart[endRange.upperBound...])
            } else {
                blocks.append(.text(remaining))
                remaining = ""
            }
        }

        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(contentsOf: parseTextAndTables(remaining))
        }

        return groupIntoSections(blocks)
    }

    static func groupIntoSections(_ blocks: [ContentBlock]) -> [ContentBlock] {
        var result: [ContentBlock] = []
        var i = 0

        while i < blocks.count {
            let block = blocks[i]
            if case .text(let content) = block, let header = extractHeader(content) {
                var sectionContent: [ContentBlock] = []
                let remainingText = removeFirstHeader(content)
                if !remainingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sectionContent.append(.text(remainingText))
                }

                i += 1
                while i < blocks.count {
                    if case .text(let nextContent) = blocks[i], extractHeader(nextContent) != nil {
                        break
                    }
                    sectionContent.append(blocks[i])
                    i += 1
                }

                result.append(.section(title: header.title, level: header.level, content: sectionContent))
            } else {
                result.append(block)
                i += 1
            }
        }

        return result
    }

    static func extractHeader(_ text: String) -> (title: String, level: Int)? {
        let lines = text.components(separatedBy: "\n")
        guard let first = lines.first else { return nil }

        if first.hasPrefix("### ") { return (String(first.dropFirst(4)), 3) }
        if first.hasPrefix("## ") { return (String(first.dropFirst(3)), 2) }
        if first.hasPrefix("# ") { return (String(first.dropFirst(2)), 1) }
        return nil
    }

    static func removeFirstHeader(_ text: String) -> String {
        text.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
    }
}
