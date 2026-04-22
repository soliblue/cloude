import Foundation
import SwiftUI

extension ChatMarkdownParser {
    static func parseToSegments(_ text: String) -> [ChatMarkdownInlineSegment] {
        var result: [ChatMarkdownInlineSegment] = []
        let lines = text.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count

            if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [ ] ") {
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

    static func parseLineToSegments(_ text: String, font: Font?) -> [ChatMarkdownInlineSegment] {
        var segments: [ChatMarkdownInlineSegment] = []
        var remaining = text[...]
        var currentText = ""

        func flushText() {
            if currentText.isEmpty { return }
            var attr = AttributedString(currentText)
            if let font = font { attr.font = font }
            segments.append(.text(attr))
            currentText = ""
        }

        while !remaining.isEmpty {
            if remaining.hasPrefix("\\") && remaining.count > 1 {
                remaining = remaining.dropFirst()
                currentText.append(remaining.removeFirst())
                continue
            }

            if let result = parseBoldItalic(&remaining, font: font) {
                flushText()
                segments.append(contentsOf: result)
                continue
            }

            if let result = parseBold(&remaining, font: font) {
                flushText()
                segments.append(contentsOf: result)
                continue
            }

            if let result = parseStrikethrough(&remaining, font: font) {
                flushText()
                segments.append(contentsOf: result)
                continue
            }

            if let result = parseItalic(&remaining, font: font) {
                flushText()
                segments.append(contentsOf: result)
                continue
            }

            if let result = parseInlineCode(&remaining) {
                flushText()
                segments.append(result)
                continue
            }

            if let result = parseFilePath(&remaining, font: font) {
                flushText()
                segments.append(result)
                continue
            }

            if let result = parseLink(&remaining, font: font) {
                flushText()
                segments.append(result)
                continue
            }

            currentText.append(remaining.removeFirst())
        }

        flushText()
        return segments
    }

    static func orderedListPrefix(_ line: String) -> String.Index? {
        var idx = line.startIndex
        while idx < line.endIndex && line[idx].isNumber {
            idx = line.index(after: idx)
        }
        if idx == line.startIndex { return nil }
        if idx >= line.endIndex || line[idx] != "." { return nil }
        idx = line.index(after: idx)
        if idx >= line.endIndex || line[idx] != " " { return nil }
        return line.index(after: idx)
    }
}
