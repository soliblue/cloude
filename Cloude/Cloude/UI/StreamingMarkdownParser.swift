//
//  StreamingMarkdownParser.swift
//  Cloude

import Foundation
import SwiftUI

enum StreamingBlock: Identifiable {
    case text(id: String, AttributedString)
    case code(id: String, content: String, language: String?, isComplete: Bool)
    case table(id: String, rows: [[String]])
    case blockquote(id: String, content: String)
    case horizontalRule(id: String)

    var id: String {
        switch self {
        case .text(let id, _): return id
        case .code(let id, _, _, _): return id
        case .table(let id, _): return id
        case .blockquote(let id, _): return id
        case .horizontalRule(let id): return id
        }
    }
}

struct StreamingMarkdownParser {
    static func parse(_ text: String) -> [StreamingBlock] {
        var blocks: [StreamingBlock] = []
        var codeCount = 0
        var tableCount = 0
        var quoteCount = 0
        var textCount = 0
        var hrCount = 0
        let lines = text.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let isLastLine = (i == lines.count - 1)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
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
                    id: "code-\(codeCount)",
                    content: codeLines.joined(separator: "\n"),
                    language: language.isEmpty ? nil : language,
                    isComplete: foundClose
                ))
                codeCount += 1
                if foundClose && i < lines.count { i += 1 }
                continue
            }

            if trimmed.hasPrefix("|") && line.contains("|") {
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

                    let isStreamingLine = (i == lines.count - 1) && !text.hasSuffix("\n")
                    if !isStreamingLine {
                        let cells = tableLine.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                        if !cells.isEmpty { tableRows.append(cells) }
                    }
                    i += 1
                }

                if !tableRows.isEmpty {
                    blocks.append(.table(id: "table-\(tableCount)", rows: tableRows))
                    tableCount += 1
                }
                continue
            }

            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []

                while i < lines.count {
                    let quoteLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if !quoteLine.hasPrefix(">") { break }
                    quoteLines.append(String(quoteLine.dropFirst()).trimmingCharacters(in: .whitespaces))
                    i += 1
                }

                if !quoteLines.isEmpty {
                    blocks.append(.blockquote(id: "quote-\(quoteCount)", content: quoteLines.joined(separator: "\n")))
                    quoteCount += 1
                }
                continue
            }

            if isHorizontalRule(trimmed) && !isLastLine {
                blocks.append(.horizontalRule(id: "hr-\(hrCount)"))
                hrCount += 1
                i += 1
                continue
            }

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
                    blocks.append(.text(id: "text-\(textCount)", parseInlineMarkdown(content)))
                    textCount += 1
                }
            }
        }

        return blocks
    }

    static func parseInlineMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString()
        let lines = text.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count

            if trimmed.hasPrefix("###### ") {
                var attr = parseInlineElements(String(trimmed.dropFirst(7)))
                attr.font = .footnote.bold()
                result.append(attr)
            } else if trimmed.hasPrefix("##### ") {
                var attr = parseInlineElements(String(trimmed.dropFirst(6)))
                attr.font = .callout.bold()
                result.append(attr)
            } else if trimmed.hasPrefix("#### ") {
                var attr = parseInlineElements(String(trimmed.dropFirst(5)))
                attr.font = .subheadline.bold()
                result.append(attr)
            } else if trimmed.hasPrefix("### ") {
                var attr = parseInlineElements(String(trimmed.dropFirst(4)))
                attr.font = .headline
                result.append(attr)
            } else if trimmed.hasPrefix("## ") {
                var attr = parseInlineElements(String(trimmed.dropFirst(3)))
                attr.font = .title3.bold()
                result.append(attr)
            } else if trimmed.hasPrefix("# ") {
                var attr = parseInlineElements(String(trimmed.dropFirst(2)))
                attr.font = .title2.bold()
                result.append(attr)
            } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [ ] ") {
                let indentStr = String(repeating: "  ", count: indent / 2)
                let isChecked = trimmed.hasPrefix("- [x] ")
                let checkbox = isChecked ? "☑ " : "☐ "
                var prefix = AttributedString(indentStr + checkbox)
                let content = parseInlineElements(String(trimmed.dropFirst(6)))
                prefix.append(content)
                result.append(prefix)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let indentStr = String(repeating: "  ", count: indent / 2)
                var bullet = AttributedString(indentStr + "• ")
                let content = parseInlineElements(String(trimmed.dropFirst(2)))
                bullet.append(content)
                result.append(bullet)
            } else if orderedListPrefix(trimmed) != nil {
                let indentStr = String(repeating: "  ", count: indent / 2)
                var attr = AttributedString(indentStr)
                attr.append(parseInlineElements(trimmed))
                result.append(attr)
            } else {
                result.append(parseInlineElements(line))
            }

            if index < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }

        return result
    }

    static func parseInlineElements(_ text: String) -> AttributedString {
        var result = AttributedString()
        var remaining = text[...]

        while !remaining.isEmpty {
            if remaining.hasPrefix("\\") && remaining.count > 1 {
                remaining = remaining.dropFirst()
                result.append(AttributedString(String(remaining.removeFirst())))
                continue
            }

            if remaining.hasPrefix("***") || remaining.hasPrefix("___") {
                let marker = String(remaining.prefix(3))
                remaining = remaining.dropFirst(3)
                var innerText = ""
                while !remaining.isEmpty {
                    if remaining.hasPrefix(marker) {
                        remaining = remaining.dropFirst(3)
                        break
                    }
                    innerText.append(remaining.removeFirst())
                }
                var parsed = parseInlineElements(innerText)
                for run in parsed.runs {
                    var newAttrs = run.attributes
                    newAttrs.font = (newAttrs.font ?? .body).bold().italic()
                    parsed[run.range].mergeAttributes(newAttrs)
                }
                result.append(parsed)
                continue
            }

            if remaining.hasPrefix("**") || remaining.hasPrefix("__") {
                let marker = String(remaining.prefix(2))
                remaining = remaining.dropFirst(2)
                var innerText = ""
                while !remaining.isEmpty {
                    if remaining.hasPrefix(marker) {
                        remaining = remaining.dropFirst(2)
                        break
                    }
                    innerText.append(remaining.removeFirst())
                }
                var parsed = parseInlineElements(innerText)
                for run in parsed.runs {
                    var newAttrs = run.attributes
                    newAttrs.font = (newAttrs.font ?? .body).bold()
                    parsed[run.range].mergeAttributes(newAttrs)
                }
                result.append(parsed)
                continue
            }

            if remaining.hasPrefix("~~") {
                remaining = remaining.dropFirst(2)
                var innerText = ""
                while !remaining.isEmpty {
                    if remaining.hasPrefix("~~") {
                        remaining = remaining.dropFirst(2)
                        break
                    }
                    innerText.append(remaining.removeFirst())
                }
                var parsed = parseInlineElements(innerText)
                for run in parsed.runs {
                    parsed[run.range].strikethroughStyle = .single
                }
                result.append(parsed)
                continue
            }

            if remaining.hasPrefix("*") || remaining.hasPrefix("_") {
                let marker = remaining.first!
                remaining = remaining.dropFirst()
                if remaining.first == " " || remaining.isEmpty {
                    result.append(AttributedString(String(marker)))
                    continue
                }
                var innerText = ""
                while !remaining.isEmpty {
                    if remaining.first == marker {
                        remaining = remaining.dropFirst()
                        break
                    }
                    innerText.append(remaining.removeFirst())
                }
                var parsed = parseInlineElements(innerText)
                for run in parsed.runs {
                    var newAttrs = run.attributes
                    newAttrs.font = (newAttrs.font ?? .body).italic()
                    parsed[run.range].mergeAttributes(newAttrs)
                }
                result.append(parsed)
                continue
            }

            if remaining.hasPrefix("`") {
                remaining = remaining.dropFirst()
                var codeText = ""
                while !remaining.isEmpty {
                    if remaining.first == "`" {
                        remaining = remaining.dropFirst()
                        break
                    }
                    codeText.append(remaining.removeFirst())
                }
                var attr = AttributedString(codeText)
                attr.font = .system(.body, design: .monospaced)
                attr.backgroundColor = .secondary.opacity(0.2)
                result.append(attr)
                continue
            }

            if remaining.hasPrefix("[") {
                if let closeIdx = remaining.firstIndex(of: "]"),
                   remaining[remaining.index(after: closeIdx)...].hasPrefix("("),
                   let urlEndIdx = remaining[closeIdx...].firstIndex(of: ")") {
                    let linkText = String(remaining[remaining.index(after: remaining.startIndex)..<closeIdx])
                    let urlStart = remaining.index(closeIdx, offsetBy: 2)
                    let urlString = String(remaining[urlStart..<urlEndIdx])
                    remaining = remaining[remaining.index(after: urlEndIdx)...]

                    var attr = AttributedString(linkText)
                    if let url = URL(string: urlString) {
                        attr.link = url
                        attr.foregroundColor = .blue
                    }
                    result.append(attr)
                    continue
                }
            }

            result.append(AttributedString(String(remaining.removeFirst())))
        }

        return result
    }

    private static func orderedListPrefix(_ line: String) -> String.Index? {
        var idx = line.startIndex
        while idx < line.endIndex && line[idx].isNumber {
            idx = line.index(after: idx)
        }
        guard idx > line.startIndex else { return nil }
        guard idx < line.endIndex && line[idx] == "." else { return nil }
        idx = line.index(after: idx)
        guard idx < line.endIndex && line[idx] == " " else { return nil }
        return line.index(after: idx)
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
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
