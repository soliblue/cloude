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

            if let headerInfo = Self.parseHeaderLine(trimmed) {
                let (level, headerText) = headerInfo
                let segments = Self.parseLineToSegments(headerText, font: Self.headerFont(for: level))
                let attributed = segmentsToAttributedString(segments)
                blocks.append(.header(id: "header-L\(i)", level: level, content: attributed, segments: segments))
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
                if Self.parseHeaderLine(lt) != nil { break }
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

    static func parseWithToolCalls(_ text: String, toolCalls: [ToolCall]) -> [StreamingBlock] {
        let topLevelTools = toolCalls
            .filter { $0.parentToolId == nil }
            .sorted { ($0.textPosition ?? 0) < ($1.textPosition ?? 0) }

        guard !topLevelTools.isEmpty else {
            return parse(text)
        }

        let childTools = toolCalls.filter { $0.parentToolId != nil }

        var result: [StreamingBlock] = []
        var currentPosition = 0
        var pendingTools: [ToolCall] = []

        for tool in topLevelTools {
            let toolPosition = tool.textPosition ?? 0

            if toolPosition > currentPosition && toolPosition <= text.count {
                if !pendingTools.isEmpty {
                    let groupWithChildren = includeChildren(parents: pendingTools, allChildren: childTools)
                    result.append(.toolGroup(id: "tools-\(currentPosition)", tools: groupWithChildren))
                    pendingTools = []
                }
                let startIdx = text.index(text.startIndex, offsetBy: currentPosition)
                let endIdx = text.index(text.startIndex, offsetBy: toolPosition)
                let segment = String(text[startIdx..<endIdx])
                if !segment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(contentsOf: parse(segment))
                }
                currentPosition = toolPosition
            }
            pendingTools.append(tool)
        }

        if !pendingTools.isEmpty {
            let groupWithChildren = includeChildren(parents: pendingTools, allChildren: childTools)
            result.append(.toolGroup(id: "tools-\(currentPosition)", tools: groupWithChildren))
        }

        if currentPosition < text.count {
            let startIdx = text.index(text.startIndex, offsetBy: currentPosition)
            let remaining = String(text[startIdx...])
            if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(contentsOf: parse(remaining))
            }
        }

        return result
    }

    private static func includeChildren(parents: [ToolCall], allChildren: [ToolCall]) -> [ToolCall] {
        let parentIds = Set(parents.map(\.toolId))
        let matchedChildren = allChildren.filter { parentIds.contains($0.parentToolId ?? "") }
        return parents + matchedChildren
    }
}
