import Foundation
import SwiftUI

extension ChatMarkdownParser {
    static func segmentsToAttributedString(
        _ segments: [ChatMarkdownInlineSegment]
    )
        -> AttributedString
    {
        var result = AttributedString()
        for segment in segments {
            switch segment {
            case .text(_, let attr):
                result.append(attr)
            case .code(_, let code):
                var attr = AttributedString(code)
                attr.font = .system(size: ThemeTokens.Text.m, weight: .regular, design: .monospaced)
                attr.backgroundColor = .secondary.opacity(ThemeTokens.Opacity.s)
                result.append(attr)
            case .filePath(_, let path):
                var attr = AttributedString(path)
                attr.font = .system(size: ThemeTokens.Text.m, weight: .medium, design: .monospaced)
                attr.foregroundColor = ThemeColor.blue
                if let url = CloudeFileURL.url(for: path) {
                    attr.link = url
                }
                result.append(attr)
            case .lineBreak:
                result.append(AttributedString("\n"))
            }
        }
        return result
    }

    static func looksLikeFilePath(_ text: String) -> Bool {
        if !text.hasPrefix("/") { return false }
        let extensions = [
            ".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic", ".svg", ".pdf",
            ".swift", ".py", ".js", ".ts", ".json", ".md", ".txt", ".html", ".css",
            ".yml", ".yaml", ".sh", ".pptx", ".plist",
            ".mp4", ".mov", ".m4v", ".avi", ".webm",
            ".mp3", ".m4a", ".wav", ".aac", ".ogg",
            ".csv", ".tsv", ".xml", ".sql", ".log", ".toml", ".env", ".lock",
        ]
        let lowered = text.lowercased()
        return extensions.contains { lowered.hasSuffix($0) }
    }
}
