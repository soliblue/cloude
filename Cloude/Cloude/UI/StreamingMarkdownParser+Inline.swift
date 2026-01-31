//
//  StreamingMarkdownParser+Inline.swift
//  Cloude

import Foundation
import SwiftUI

extension StreamingMarkdownParser {
    static func parseInlineMarkdown(_ text: String) -> AttributedString {
        let segments = parseToSegments(text)
        return segmentsToAttributedString(segments)
    }

    static func parseToSegments(_ text: String) -> [InlineSegment] {
        var result: [InlineSegment] = []
        let lines = text.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count

            if trimmed.hasPrefix("###### ") {
                let segments = parseLineToSegments(String(trimmed.dropFirst(7)), font: .footnote.bold())
                result.append(contentsOf: segments)
            } else if trimmed.hasPrefix("##### ") {
                let segments = parseLineToSegments(String(trimmed.dropFirst(6)), font: .callout.bold())
                result.append(contentsOf: segments)
            } else if trimmed.hasPrefix("#### ") {
                let segments = parseLineToSegments(String(trimmed.dropFirst(5)), font: .subheadline.bold())
                result.append(contentsOf: segments)
            } else if trimmed.hasPrefix("### ") {
                let segments = parseLineToSegments(String(trimmed.dropFirst(4)), font: .headline)
                result.append(contentsOf: segments)
            } else if trimmed.hasPrefix("## ") {
                let segments = parseLineToSegments(String(trimmed.dropFirst(3)), font: .title3.bold())
                result.append(contentsOf: segments)
            } else if trimmed.hasPrefix("# ") {
                let segments = parseLineToSegments(String(trimmed.dropFirst(2)), font: .title2.bold())
                result.append(contentsOf: segments)
            } else if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [ ] ") {
                let indentStr = String(repeating: "  ", count: indent / 2)
                let isChecked = trimmed.hasPrefix("- [x] ")
                let checkbox = isChecked ? "☑ " : "☐ "
                result.append(.text(AttributedString(indentStr + checkbox)))
                let segments = parseLineToSegments(String(trimmed.dropFirst(6)), font: nil)
                result.append(contentsOf: segments)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let indentStr = String(repeating: "  ", count: indent / 2)
                result.append(.text(AttributedString(indentStr + "• ")))
                let segments = parseLineToSegments(String(trimmed.dropFirst(2)), font: nil)
                result.append(contentsOf: segments)
            } else if orderedListPrefix(trimmed) != nil {
                let indentStr = String(repeating: "  ", count: indent / 2)
                result.append(.text(AttributedString(indentStr)))
                let segments = parseLineToSegments(trimmed, font: nil)
                result.append(contentsOf: segments)
            } else {
                let segments = parseLineToSegments(line, font: nil)
                result.append(contentsOf: segments)
            }

            if index < lines.count - 1 {
                result.append(.lineBreak())
            }
        }

        return result
    }

    private static func parseLineToSegments(_ text: String, font: Font?) -> [InlineSegment] {
        var segments: [InlineSegment] = []
        var remaining = text[...]
        var currentText = ""
        var currentIntents: InlinePresentationIntent = []
        var currentStrikethrough = false
        var currentLink: URL? = nil

        func flushText() {
            guard !currentText.isEmpty else { return }
            var attr = AttributedString(currentText)
            if let font = font {
                attr.font = font
            }
            if !currentIntents.isEmpty {
                attr.inlinePresentationIntent = currentIntents
            }
            if currentStrikethrough {
                attr.strikethroughStyle = .single
            }
            if let url = currentLink {
                attr.link = url
                attr.foregroundColor = .blue
            }
            segments.append(.text(attr))
            currentText = ""
        }

        while !remaining.isEmpty {
            if remaining.hasPrefix("\\") && remaining.count > 1 {
                remaining = remaining.dropFirst()
                currentText.append(remaining.removeFirst())
                continue
            }

            if remaining.hasPrefix("***") || remaining.hasPrefix("___") {
                flushText()
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
                let innerSegments = parseLineToSegments(innerText, font: font)
                for segment in innerSegments {
                    if case .text(_, var attr) = segment {
                        for run in attr.runs {
                            let existing = attr[run.range].inlinePresentationIntent ?? []
                            attr[run.range].inlinePresentationIntent = existing.union([.stronglyEmphasized, .emphasized])
                        }
                        segments.append(.text(attr))
                    } else {
                        segments.append(segment)
                    }
                }
                continue
            }

            if remaining.hasPrefix("**") || remaining.hasPrefix("__") {
                flushText()
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
                let innerSegments = parseLineToSegments(innerText, font: font)
                for segment in innerSegments {
                    if case .text(_, var attr) = segment {
                        for run in attr.runs {
                            let existing = attr[run.range].inlinePresentationIntent ?? []
                            attr[run.range].inlinePresentationIntent = existing.union(.stronglyEmphasized)
                        }
                        segments.append(.text(attr))
                    } else {
                        segments.append(segment)
                    }
                }
                continue
            }

            if remaining.hasPrefix("~~") {
                flushText()
                remaining = remaining.dropFirst(2)
                var innerText = ""
                while !remaining.isEmpty {
                    if remaining.hasPrefix("~~") {
                        remaining = remaining.dropFirst(2)
                        break
                    }
                    innerText.append(remaining.removeFirst())
                }
                let innerSegments = parseLineToSegments(innerText, font: font)
                for segment in innerSegments {
                    if case .text(_, var attr) = segment {
                        for run in attr.runs {
                            attr[run.range].strikethroughStyle = .single
                        }
                        segments.append(.text(attr))
                    } else {
                        segments.append(segment)
                    }
                }
                continue
            }

            if remaining.hasPrefix("*") || remaining.hasPrefix("_") {
                let marker = remaining.first!
                let nextIdx = remaining.index(after: remaining.startIndex)
                if nextIdx < remaining.endIndex && remaining[nextIdx] != " " {
                    flushText()
                    remaining = remaining.dropFirst()
                    var innerText = ""
                    while !remaining.isEmpty {
                        if remaining.first == marker {
                            remaining = remaining.dropFirst()
                            break
                        }
                        innerText.append(remaining.removeFirst())
                    }
                    let innerSegments = parseLineToSegments(innerText, font: font)
                    for segment in innerSegments {
                        if case .text(_, var attr) = segment {
                            for run in attr.runs {
                                let existing = attr[run.range].inlinePresentationIntent ?? []
                                attr[run.range].inlinePresentationIntent = existing.union(.emphasized)
                            }
                            segments.append(.text(attr))
                        } else {
                            segments.append(segment)
                        }
                    }
                    continue
                }
            }

            if remaining.hasPrefix("`") {
                flushText()
                remaining = remaining.dropFirst()
                var codeText = ""
                while !remaining.isEmpty {
                    if remaining.first == "`" {
                        remaining = remaining.dropFirst()
                        break
                    }
                    codeText.append(remaining.removeFirst())
                }
                segments.append(.code(codeText))
                continue
            }

            if remaining.hasPrefix("[") {
                if let closeIdx = remaining.firstIndex(of: "]"),
                   remaining.index(after: closeIdx) < remaining.endIndex,
                   remaining[remaining.index(after: closeIdx)...].hasPrefix("("),
                   let urlEndIdx = remaining[closeIdx...].firstIndex(of: ")") {
                    flushText()
                    let linkText = String(remaining[remaining.index(after: remaining.startIndex)..<closeIdx])
                    let urlStart = remaining.index(closeIdx, offsetBy: 2)
                    let urlString = String(remaining[urlStart..<urlEndIdx])
                    remaining = remaining[remaining.index(after: urlEndIdx)...]

                    var attr = AttributedString(linkText)
                    if let font = font {
                        attr.font = font
                    }
                    if let url = URL(string: urlString) {
                        attr.link = url
                        attr.foregroundColor = .blue
                    }
                    segments.append(.text(attr))
                    continue
                }
            }

            currentText.append(remaining.removeFirst())
        }

        flushText()
        return segments
    }

    static func segmentsToAttributedString(_ segments: [InlineSegment]) -> AttributedString {
        var result = AttributedString()
        for segment in segments {
            switch segment {
            case .text(_, let attr):
                result.append(attr)
            case .code(_, let code):
                var attr = AttributedString("\u{2009}\(code)\u{2009}")
                attr.font = .system(size: 14, weight: .regular, design: .monospaced)
                attr.backgroundColor = .secondary.opacity(0.2)
                result.append(attr)
            case .lineBreak:
                result.append(AttributedString("\n"))
            }
        }
        return result
    }

    static func parseInlineElements(_ text: String) -> AttributedString {
        let segments = parseLineToSegments(text, font: nil)
        return segmentsToAttributedString(segments)
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
