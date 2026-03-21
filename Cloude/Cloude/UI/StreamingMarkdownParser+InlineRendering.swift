// StreamingMarkdownParser+InlineRendering.swift

import Foundation
import SwiftUI

extension StreamingMarkdownParser {
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

    static func looksLikeFilePath(_ text: String) -> Bool {
        guard text.hasPrefix("/") else { return false }
        let imageExtensions = [".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic", ".svg", ".pdf"]
        let codeExtensions = [".swift", ".py", ".js", ".ts", ".json", ".md", ".txt", ".html", ".css", ".yml", ".yaml", ".sh", ".pptx", ".plist"]
        let videoExtensions = [".mp4", ".mov", ".m4v", ".avi", ".webm"]
        let audioExtensions = [".mp3", ".m4a", ".wav", ".aac", ".ogg"]
        let dataExtensions = [".csv", ".tsv", ".xml", ".sql", ".log", ".toml", ".env", ".lock"]
        let allExtensions = imageExtensions + codeExtensions + videoExtensions + audioExtensions + dataExtensions
        let lowered = text.lowercased()
        return allExtensions.contains { lowered.hasSuffix($0) }
    }
}
