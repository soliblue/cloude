import Foundation

extension ChatMarkdownParser {
    static func parseCodeBlock(
        lines: [String], index i: inout Int, lineOffset: Int = 0
    )
        -> ChatMarkdownBlock
    {
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

        let block = ChatMarkdownBlock.code(
            id: "code-L\(startLine + lineOffset)",
            content: codeLines.joined(separator: "\n"),
            language: language.isEmpty ? nil : language,
            isComplete: foundClose
        )
        if foundClose && i < lines.count { i += 1 }
        return block
    }

    static func parseTable(
        lines: [String], index i: inout Int, originalText: String, lineOffset: Int = 0
    )
        -> ChatMarkdownBlock?
    {
        let startLine = i
        var tableRows: [[String]] = []

        while i < lines.count {
            let tableLine = lines[i]
            let tableTrimmed = tableLine.trimmingCharacters(in: .whitespaces)
            if !tableTrimmed.hasPrefix("|") && !tableLine.contains("|") { break }

            let isSeparator =
                tableLine.contains("-") && !tableLine.contains(where: { $0.isLetter })
            if isSeparator {
                i += 1
                continue
            }

            let originalHasTrailingNewline =
                originalText.hasSuffix("\n") || originalText.hasSuffix("\n ")
            let isStreamingLine = (i == lines.count - 1) && !originalHasTrailingNewline
            if !isStreamingLine {
                let cells = tableLine.split(separator: "|").map {
                    String($0).trimmingCharacters(in: .whitespaces)
                }
                if !cells.isEmpty { tableRows.append(cells) }
            }
            i += 1
        }

        if tableRows.isEmpty { return nil }
        return .table(id: "table-L\(startLine + lineOffset)", rows: tableRows)
    }

    static func parseBlockquote(
        lines: [String], index i: inout Int, lineOffset: Int = 0
    )
        -> ChatMarkdownBlock?
    {
        let startLine = i
        var quoteLines: [String] = []

        while i < lines.count {
            let quoteLine = lines[i].trimmingCharacters(in: .whitespaces)
            if !quoteLine.hasPrefix(">") { break }
            quoteLines.append(String(quoteLine.dropFirst()).trimmingCharacters(in: .whitespaces))
            i += 1
        }

        if quoteLines.isEmpty { return nil }
        return .blockquote(
            id: "quote-L\(startLine + lineOffset)", content: quoteLines.joined(separator: "\n"))
    }

    static func parseTextBlock(
        lines: [String], index i: inout Int, lineOffset: Int = 0
    )
        -> ChatMarkdownBlock?
    {
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
            textLines.append(l)
            i += 1
        }

        if textLines.isEmpty { return nil }
        let content = textLines.joined(separator: "\n")
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        let segments = parseToSegments(content)
        return .text(
            id: "text-L\(textStartLine + lineOffset)", segmentsToAttributedString(segments),
            segments: segments)
    }
}
