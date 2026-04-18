import Foundation
import SwiftUI

extension StreamingMarkdownParser {
    static func parseBoldItalic(_ remaining: inout Substring, font: Font?) -> [InlineSegment]? {
        guard remaining.hasPrefix("***") || remaining.hasPrefix("___") else { return nil }
        let marker = String(remaining.prefix(3))
        remaining = remaining.dropFirst(3)
        let innerText = extractUntil(&remaining, marker: marker)
        return applyIntent(parseLineToSegments(innerText, font: font), intents: [.stronglyEmphasized, .emphasized])
    }

    static func parseStrikethrough(_ remaining: inout Substring, font: Font?) -> [InlineSegment]? {
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

    static func parseItalic(_ remaining: inout Substring, font: Font?) -> [InlineSegment]? {
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

    static func parseBold(_ remaining: inout Substring, font: Font?) -> [InlineSegment]? {
        guard remaining.hasPrefix("**") || remaining.hasPrefix("__") else { return nil }
        let marker = String(remaining.prefix(2))
        remaining = remaining.dropFirst(2)
        let innerText = extractUntil(&remaining, marker: marker)
        return applyIntent(parseLineToSegments(innerText, font: font), intents: .stronglyEmphasized)
    }

    static func parseInlineCode(_ remaining: inout Substring) -> InlineSegment? {
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

    static func parseFilePath(_ remaining: inout Substring, font: Font?) -> InlineSegment? {
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

    static func parseLink(_ remaining: inout Substring, font: Font?) -> InlineSegment? {
        guard remaining.hasPrefix("["),
              let closeIdx = remaining.firstIndex(of: "]"),
              remaining.index(after: closeIdx) < remaining.endIndex,
              remaining[remaining.index(after: closeIdx)...].hasPrefix("("),
              let urlEndIdx = remaining[closeIdx...].firstIndex(of: ")") else { return nil }

        let linkText = String(remaining[remaining.index(after: remaining.startIndex)..<closeIdx])
        let urlStart = remaining.index(closeIdx, offsetBy: 2)
        let urlString = String(remaining[urlStart..<urlEndIdx])
        remaining = remaining[remaining.index(after: urlEndIdx)...]

        let strippedText = linkText
            .replacingOccurrences(of: "***", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
        var attr = AttributedString(strippedText)
        if let font = font { attr.font = font }
        if linkText.contains("**") || linkText.contains("__") {
            attr.inlinePresentationIntent = .stronglyEmphasized
        }
        if let url = URL(string: urlString) {
            attr.link = url
            attr.foregroundColor = AppColor.blue
        }
        return .text(attr)
    }

    static func extractUntil(_ remaining: inout Substring, marker: String) -> String {
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

    static func applyIntent(_ segments: [InlineSegment], intents: InlinePresentationIntent) -> [InlineSegment] {
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

}
