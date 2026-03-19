import Foundation
import SwiftUI
import CloudeShared

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

            if trimmed.isEmpty {
                i += 1
                continue
            }

            if line.hasPrefix("```") {
                blocks.append(parseCodeBlock(lines: lines, index: &i))
                continue
            }

            if trimmed.hasPrefix("|") && line.contains("|") {
                if let table = parseTable(lines: lines, index: &i, originalText: text) {
                    blocks.append(table)
                }
                continue
            }

            if trimmed.hasPrefix(">") {
                if let quote = parseBlockquote(lines: lines, index: &i) {
                    blocks.append(quote)
                }
                continue
            }

            if isHorizontalRule(trimmed) && !isLastLine {
                blocks.append(.horizontalRule(id: "hr-L\(i)"))
                i += 1
                continue
            }

            if let headerInfo = parseHeaderLine(trimmed) {
                let (level, headerText) = headerInfo
                let segments = parseLineToSegments(headerText, font: headerFont(for: level))
                let attributed = segmentsToAttributedString(segments)
                blocks.append(.header(id: "header-L\(i)", level: level, content: attributed, segments: segments))
                i += 1
                continue
            }

            if let xmlBlock = parseXMLBlock(lines: lines, index: &i) {
                blocks.append(xmlBlock)
                continue
            }

            if let textBlock = parseTextBlock(lines: lines, index: &i) {
                blocks.append(textBlock)
            }
        }

        return blocks
    }

    private static func parseCodeBlock(lines: [String], index i: inout Int) -> StreamingBlock {
        let startLine = i
        let language = String(lines[i].dropFirst(3)).trimmingCharacters(in: .whitespaces)
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

        let block = StreamingBlock.code(
            id: "code-L\(startLine)",
            content: codeLines.joined(separator: "\n"),
            language: language.nilIfEmpty,
            isComplete: foundClose
        )
        if foundClose && i < lines.count { i += 1 }
        return block
    }

    private static func parseTable(lines: [String], index i: inout Int, originalText: String) -> StreamingBlock? {
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

            let originalHasTrailingNewline = originalText.hasSuffix("\n") || originalText.hasSuffix("\n ")
            let isStreamingLine = (i == lines.count - 1) && !originalHasTrailingNewline
            if !isStreamingLine {
                let cells = tableLine.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                if !cells.isEmpty { tableRows.append(cells) }
            }
            i += 1
        }

        guard !tableRows.isEmpty else { return nil }
        return .table(id: "table-L\(startLine)", rows: tableRows)
    }

    private static func parseBlockquote(lines: [String], index i: inout Int) -> StreamingBlock? {
        let startLine = i
        var quoteLines: [String] = []

        while i < lines.count {
            let quoteLine = lines[i].trimmingCharacters(in: .whitespaces)
            if !quoteLine.hasPrefix(">") { break }
            quoteLines.append(String(quoteLine.dropFirst()).trimmingCharacters(in: .whitespaces))
            i += 1
        }

        guard !quoteLines.isEmpty else { return nil }
        return .blockquote(id: "quote-L\(startLine)", content: quoteLines.joined(separator: "\n"))
    }

    private static func parseTextBlock(lines: [String], index i: inout Int) -> StreamingBlock? {
        let textStartLine = i
        var textLines: [String] = []
        while i < lines.count {
            let l = lines[i]
            let lt = l.trimmingCharacters(in: .whitespaces)
            if lt.isEmpty { break }
            if l.hasPrefix("```") { break }
            if lt.hasPrefix("|") && l.contains("|") { break }
            if lt.hasPrefix(">") { break }
            if isHorizontalRule(lt) && i < lines.count - 1 { break }
            if parseHeaderLine(lt) != nil { break }
            if looksLikeXMLBlock(lt) { break }
            textLines.append(l)
            i += 1
        }

        guard !textLines.isEmpty else { return nil }
        let content = textLines.joined(separator: "\n")
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let segments = parseToSegments(content)
        return .text(id: "text-L\(textStartLine)", segmentsToAttributedString(segments), segments: segments)
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

    static func looksLikeXMLBlock(_ line: String) -> Bool {
        guard line.hasPrefix("<") else { return false }
        let xmlTagPattern = #"^</?[a-zA-Z][a-zA-Z0-9_:.-]*[\s/>]"#
        return line.range(of: xmlTagPattern, options: .regularExpression) != nil
    }

    private static func parseXMLBlock(lines: [String], index i: inout Int) -> StreamingBlock? {
        let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
        guard looksLikeXMLBlock(trimmed) else { return nil }

        let startLine = i
        var xmlLines: [String] = []

        if trimmed.hasSuffix("/>") || isSelfClosingOneLine(trimmed) {
            xmlLines.append(lines[i])
            i += 1
        } else {
            let tagName = extractOpeningTagName(trimmed)
            guard let tagName, !tagName.isEmpty else { return nil }

            var depth = 0
            while i < lines.count {
                let l = lines[i]
                xmlLines.append(l)

                depth += countOpens(l, tag: tagName) - countCloses(l, tag: tagName)
                i += 1

                if depth <= 0 { break }
            }
        }

        let raw = xmlLines.joined(separator: "\n")
        let nodes = XMLNode.parse(raw)
        guard !nodes.isEmpty else { return nil }
        return .xml(id: "xml-L\(startLine)", nodes: nodes)
    }

    private static func isSelfClosingOneLine(_ line: String) -> Bool {
        guard let tagName = extractOpeningTagName(line) else { return false }
        return line.contains("</\(tagName)>")
    }

    private static func extractOpeningTagName(_ line: String) -> String? {
        guard line.hasPrefix("<") else { return nil }
        let afterBracket = line.dropFirst()
        var name = ""
        for c in afterBracket {
            if c.isLetter || c.isNumber || c == "_" || c == "-" || c == ":" || c == "." {
                name.append(c)
            } else {
                break
            }
        }
        return name.isEmpty ? nil : name
    }

    private static func countOpens(_ line: String, tag: String) -> Int {
        var count = 0
        var search = line[...]
        let pattern = "<\(tag)"
        while let range = search.range(of: pattern) {
            let afterTag = range.upperBound < search.endIndex ? search[range.upperBound] : Character(">")
            if afterTag == " " || afterTag == ">" || afterTag == "/" {
                count += 1
            }
            search = search[range.upperBound...]
        }
        return count
    }

    private static func countCloses(_ line: String, tag: String) -> Int {
        var count = 0
        var search = line[...]
        let pattern = "</\(tag)>"
        while let range = search.range(of: pattern) {
            count += 1
            search = search[range.upperBound...]
        }
        return count
    }
}
