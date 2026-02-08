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

    static func parseLineToSegments(_ text: String, font: Font?) -> [InlineSegment] {
        var segments: [InlineSegment] = []
        var remaining = text[...]
        var currentText = ""

        func flushText() {
            guard !currentText.isEmpty else { return }
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

    private static func parseBoldItalic(_ remaining: inout Substring, font: Font?) -> [InlineSegment]? {
        guard remaining.hasPrefix("***") || remaining.hasPrefix("___") else { return nil }
        let marker = String(remaining.prefix(3))
        remaining = remaining.dropFirst(3)
        let innerText = extractUntil(&remaining, marker: marker)
        return applyIntent(parseLineToSegments(innerText, font: font), intents: [.stronglyEmphasized, .emphasized])
    }

    private static func parseStrikethrough(_ remaining: inout Substring, font: Font?) -> [InlineSegment]? {
        guard remaining.hasPrefix("~~") else { return nil }
        remaining = remaining.dropFirst(2)
        let innerText = extractUntil(&remaining, marker: "~~")
        let innerSegments = parseLineToSegments(innerText, font: font)
        return innerSegments.map { segment in
            if case .text(_, var attr) = segment {
                for run in attr.runs { attr[run.range].strikethroughStyle = .single }
                return .text(attr)
            }
            return segment
        }
    }

    private static func parseItalic(_ remaining: inout Substring, font: Font?) -> [InlineSegment]? {
        guard remaining.hasPrefix("*") || remaining.hasPrefix("_"),
              let marker = remaining.first else { return nil }
        let nextIdx = remaining.index(after: remaining.startIndex)
        guard nextIdx < remaining.endIndex && remaining[nextIdx] != " " else { return nil }
        remaining = remaining.dropFirst()
        var innerText = ""
        while !remaining.isEmpty {
            if remaining.first == marker {
                remaining = remaining.dropFirst()
                break
            }
            innerText.append(remaining.removeFirst())
        }
        return applyIntent(parseLineToSegments(innerText, font: font), intents: .emphasized)
    }

    private static func parseBold(_ remaining: inout Substring, font: Font?) -> [InlineSegment]? {
        guard remaining.hasPrefix("**") || remaining.hasPrefix("__") else { return nil }
        let marker = String(remaining.prefix(2))
        remaining = remaining.dropFirst(2)
        let innerText = extractUntil(&remaining, marker: marker)
        return applyIntent(parseLineToSegments(innerText, font: font), intents: .stronglyEmphasized)
    }

    private static func parseInlineCode(_ remaining: inout Substring) -> InlineSegment? {
        guard remaining.hasPrefix("`") else { return nil }
        remaining = remaining.dropFirst()
        var codeText = ""
        while !remaining.isEmpty {
            if remaining.first == "`" {
                remaining = remaining.dropFirst()
                break
            }
            codeText.append(remaining.removeFirst())
        }
        return looksLikeFilePath(codeText) ? .filePath(codeText) : .code(codeText)
    }

    private static func parseFilePath(_ remaining: inout Substring, font: Font?) -> InlineSegment? {
        guard remaining.hasPrefix("/Users/") || remaining.hasPrefix("/tmp/") || remaining.hasPrefix("/var/") else { return nil }
        var pathText = ""
        while let ch = remaining.first {
            if ch.isWhitespace || ch == ")" || ch == "]" || ch == "," || ch == ";" { break }
            pathText.append(remaining.removeFirst())
        }
        if looksLikeFilePath(pathText) {
            return .filePath(pathText)
        }
        var attr = AttributedString(pathText)
        if let font = font { attr.font = font }
        return .text(attr)
    }

    private static func parseLink(_ remaining: inout Substring, font: Font?) -> InlineSegment? {
        guard remaining.hasPrefix("["),
              let closeIdx = remaining.firstIndex(of: "]"),
              remaining.index(after: closeIdx) < remaining.endIndex,
              remaining[remaining.index(after: closeIdx)...].hasPrefix("("),
              let urlEndIdx = remaining[closeIdx...].firstIndex(of: ")") else { return nil }

        let linkText = String(remaining[remaining.index(after: remaining.startIndex)..<closeIdx])
        let urlStart = remaining.index(closeIdx, offsetBy: 2)
        let urlString = String(remaining[urlStart..<urlEndIdx])
        remaining = remaining[remaining.index(after: urlEndIdx)...]

        var attr = AttributedString(linkText)
        if let font = font { attr.font = font }
        if let url = URL(string: urlString) {
            attr.link = url
            attr.foregroundColor = .blue
        }
        return .text(attr)
    }

    private static func extractUntil(_ remaining: inout Substring, marker: String) -> String {
        var innerText = ""
        while !remaining.isEmpty {
            if remaining.hasPrefix(marker) {
                remaining = remaining.dropFirst(marker.count)
                break
            }
            innerText.append(remaining.removeFirst())
        }
        return innerText
    }

    private static func applyIntent(_ segments: [InlineSegment], intents: InlinePresentationIntent) -> [InlineSegment] {
        segments.map { segment in
            if case .text(_, var attr) = segment {
                for run in attr.runs {
                    let existing = attr[run.range].inlinePresentationIntent ?? []
                    attr[run.range].inlinePresentationIntent = existing.union(intents)
                }
                return .text(attr)
            }
            return segment
        }
    }

    static func segmentsToAttributedString(_ segments: [InlineSegment]) -> AttributedString {
        var result = AttributedString()
        for segment in segments {
            switch segment {
            case .text(_, let attr):
                result.append(attr)
            case .code(_, let code):
                var attr = AttributedString(code)
                attr.font = .system(size: 14, weight: .regular, design: .monospaced)
                attr.backgroundColor = .secondary.opacity(0.1)
                result.append(attr)
            case .filePath(_, let path):
                var attr = AttributedString(path)
                attr.font = .system(size: 14, weight: .medium, design: .monospaced)
                attr.foregroundColor = .accentColor
                if let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let url = URL(string: "cloude://file\(encodedPath)") {
                    attr.link = url
                }
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

    private static func looksLikeFilePath(_ text: String) -> Bool {
        guard text.hasPrefix("/") else { return false }
        let imageExtensions = [".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic", ".svg", ".pdf"]
        let codeExtensions = [".swift", ".py", ".js", ".ts", ".json", ".md", ".txt", ".html", ".css", ".yml", ".yaml", ".sh", ".pptx", ".plist"]
        let dataExtensions = [".csv", ".tsv", ".xml", ".sql", ".log", ".toml", ".env", ".lock"]
        let allExtensions = imageExtensions + codeExtensions + dataExtensions
        let lowered = text.lowercased()
        return allExtensions.contains { lowered.hasSuffix($0) }
    }
}
