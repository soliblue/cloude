//
//  StreamingMarkdownParser+Inline.swift
//  Cloude

import Foundation
import SwiftUI

extension StreamingMarkdownParser {
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
                    let existing = parsed[run.range].inlinePresentationIntent ?? []
                    parsed[run.range].inlinePresentationIntent = existing.union([.stronglyEmphasized, .emphasized])
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
                    let existing = parsed[run.range].inlinePresentationIntent ?? []
                    parsed[run.range].inlinePresentationIntent = existing.union(.stronglyEmphasized)
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
                    let existing = parsed[run.range].inlinePresentationIntent ?? []
                    parsed[run.range].inlinePresentationIntent = existing.union(.emphasized)
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

                    var attr = parseInlineElements(linkText)
                    if let url = URL(string: urlString) {
                        for run in attr.runs {
                            attr[run.range].link = url
                            attr[run.range].foregroundColor = .blue
                        }
                    }
                    result.append(attr)
                    continue
                }
            }

            result.append(AttributedString(String(remaining.removeFirst())))
        }

        return result
    }

    static func orderedListPrefix(_ line: String) -> String.Index? {
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
}
