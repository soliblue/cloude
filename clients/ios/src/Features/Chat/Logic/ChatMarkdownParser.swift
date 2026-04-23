import Foundation
import SwiftUI

enum ChatMarkdownParser {
    static func parse(_ text: String, lineOffset: Int = 0) -> [ChatMarkdownBlock] {
        PerfCounters.bumpParse(hash: text.hashValue)
        var blocks: [ChatMarkdownBlock] = []
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty { return blocks }
        let lines = normalized.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let isLastLine = (i == lines.count - 1)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                i += 1
                continue
            }

            if line.hasPrefix("```") {
                blocks.append(parseCodeBlock(lines: lines, index: &i, lineOffset: lineOffset))
                continue
            }

            if trimmed.hasPrefix("|") && line.contains("|") {
                if let table = parseTable(
                    lines: lines, index: &i, originalText: text, lineOffset: lineOffset)
                {
                    blocks.append(table)
                }
                continue
            }

            if trimmed.hasPrefix(">") {
                if let quote = parseBlockquote(lines: lines, index: &i, lineOffset: lineOffset) {
                    blocks.append(quote)
                }
                continue
            }

            if isHorizontalRule(trimmed) && !isLastLine {
                blocks.append(.horizontalRule(id: "hr-L\(i + lineOffset)"))
                i += 1
                continue
            }

            if let headerInfo = parseHeaderLine(trimmed) {
                let (level, headerText) = headerInfo
                let segments = parseLineToSegments(headerText, font: headerFont(for: level))
                let attributed = segmentsToAttributedString(segments)
                blocks.append(
                    .header(
                        id: "header-L\(i + lineOffset)", level: level, content: attributed,
                        segments: segments))
                i += 1
                continue
            }

            if let textBlock = parseTextBlock(lines: lines, index: &i, lineOffset: lineOffset) {
                blocks.append(textBlock)
            }
        }

        return blocks
    }

    static func isHorizontalRule(_ line: String) -> Bool {
        if line.count < 3 { return false }
        let dashOnly = line.allSatisfy { $0 == "-" || $0 == " " }
        let starOnly = line.allSatisfy { $0 == "*" || $0 == " " }
        let underscoreOnly = line.allSatisfy { $0 == "_" || $0 == " " }
        let dashCount = line.filter { $0 == "-" }.count
        let starCount = line.filter { $0 == "*" }.count
        let underscoreCount = line.filter { $0 == "_" }.count
        return (dashOnly && dashCount >= 3) || (starOnly && starCount >= 3)
            || (underscoreOnly && underscoreCount >= 3)
    }

    static func parseHeaderLine(_ line: String) -> (level: Int, text: String)? {
        if line.hasPrefix("###### ") { return (6, String(line.dropFirst(7))) }
        if line.hasPrefix("##### ") { return (5, String(line.dropFirst(6))) }
        if line.hasPrefix("#### ") { return (4, String(line.dropFirst(5))) }
        if line.hasPrefix("### ") { return (3, String(line.dropFirst(4))) }
        if line.hasPrefix("## ") { return (2, String(line.dropFirst(3))) }
        if line.hasPrefix("# ") { return (1, String(line.dropFirst(2))) }
        return nil
    }

    static func headerFont(for level: Int) -> Font {
        switch level {
        case 1: return .title2.bold()
        case 2: return .title3.bold()
        case 3: return .headline
        case 4: return .subheadline.bold()
        case 5: return .callout.bold()
        default: return .footnote.bold()
        }
    }
}
