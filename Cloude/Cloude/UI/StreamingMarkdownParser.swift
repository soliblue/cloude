//
//  StreamingMarkdownParser.swift
//  Cloude

import Foundation
import SwiftUI

struct StreamingMarkdownParser {
    static func parse(_ text: String) -> [StreamingBlock] {
        var blocks: [StreamingBlock] = []
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return blocks }
        let lines = normalizedText.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let isLastLine = (i == lines.count - 1)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                let startLine = i
                let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                var foundClose = false

                while i < lines.count {
                    if lines[i].hasPrefix("```") {
                        foundClose = true
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }

                blocks.append(.code(
                    id: "code-L\(startLine)",
                    content: codeLines.joined(separator: "\n"),
                    language: language.isEmpty ? nil : language,
                    isComplete: foundClose
                ))
                if foundClose && i < lines.count { i += 1 }
                continue
            }

            if trimmed.hasPrefix("|") && line.contains("|") {
                let startLine = i
                var tableRows: [[String]] = []

                while i < lines.count {
                    let tableLine = lines[i]
                    let tableTrimmed = tableLine.trimmingCharacters(in: .whitespaces)

                    if !tableTrimmed.hasPrefix("|") && !tableLine.contains("|") { break }

                    let isSeparator = tableLine.contains("-") && !tableLine.contains(where: { $0.isLetter })
                    if isSeparator {
                        i += 1
                        continue
                    }

                    let originalHasTrailingNewline = text.hasSuffix("\n") || text.hasSuffix("\n ")
                    let isStreamingLine = (i == lines.count - 1) && !originalHasTrailingNewline
                    if !isStreamingLine {
                        let cells = tableLine.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                        if !cells.isEmpty { tableRows.append(cells) }
                    }
                    i += 1
                }

                if !tableRows.isEmpty {
                    blocks.append(.table(id: "table-L\(startLine)", rows: tableRows))
                }
                continue
            }

            if trimmed.hasPrefix(">") {
                let startLine = i
                var quoteLines: [String] = []

                while i < lines.count {
                    let quoteLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if !quoteLine.hasPrefix(">") { break }
                    quoteLines.append(String(quoteLine.dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }

                if !quoteLines.isEmpty {
                    blocks.append(.blockquote(id: "quote-L\(startLine)", content: quoteLines.joined(separator: "\n")))
                }
                continue
            }

            if isHorizontalRule(trimmed) && !isLastLine {
                blocks.append(.horizontalRule(id: "hr-L\(i)"))
                i += 1
                continue
            }

            let textStartLine = i
            var textLines: [String] = []
            while i < lines.count {
                let l = lines[i]
                let lt = l.trimmingCharacters(in: .whitespaces)
                if l.hasPrefix("```") { break }
                if lt.hasPrefix("|") && l.contains("|") { break }
                if lt.hasPrefix(">") { break }
                if isHorizontalRule(lt) && i < lines.count - 1 { break }
                textLines.append(l)
                i += 1
            }

            if !textLines.isEmpty {
                let content = textLines.joined(separator: "\n")
                if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let segments = parseToSegments(content)
                    blocks.append(.text(id: "text-L\(textStartLine)", segmentsToAttributedString(segments), segments: segments))
                }
            }
        }

        return blocks
    }

    static func isHorizontalRule(_ line: String) -> Bool {
        guard line.count >= 3 else { return false }
        let dashOnly = line.allSatisfy { $0 == "-" || $0 == " " }
        let starOnly = line.allSatisfy { $0 == "*" || $0 == " " }
        let underscoreOnly = line.allSatisfy { $0 == "_" || $0 == " " }
        let dashCount = line.filter { $0 == "-" }.count
        let starCount = line.filter { $0 == "*" }.count
        let underscoreCount = line.filter { $0 == "_" }.count
        return (dashOnly && dashCount >= 3) || (starOnly && starCount >= 3) || (underscoreOnly && underscoreCount >= 3)
    }
}
