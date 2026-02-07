import SwiftUI
import UIKit
import CloudeShared

enum InlineSegment: Identifiable, Equatable {
    case text(id: UUID = UUID(), AttributedString)
    case code(id: UUID = UUID(), String)
    case filePath(id: UUID = UUID(), String)
    case lineBreak(id: UUID = UUID())

    var id: UUID {
        switch self {
        case .text(let id, _): return id
        case .code(let id, _): return id
        case .filePath(let id, _): return id
        case .lineBreak(let id): return id
        }
    }
}

struct InlineTextView: View {
    let segments: [InlineSegment]

    var body: some View {
        Text(buildAttributedString())
            .textSelection(.enabled)
    }

    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()
        for segment in segments {
            switch segment {
            case .text(_, let attr):
                result.append(attr)
            case .code(_, let code):
                var attr = AttributedString(code)
                attr.font = .system(size: UIFont.preferredFont(forTextStyle: .body).pointSize - 1, weight: .regular, design: .monospaced)
                attr.backgroundColor = Color(.secondarySystemFill)
                result.append(attr)
            case .filePath(_, let path):
                let filename = path.lastPathComponent
                let icon = fileIconChar(for: filename)
                let nbsp = "\u{00A0}"
                let pillText = "\(nbsp)\(icon)\(nbsp)\(filename.replacingOccurrences(of: " ", with: nbsp))\(nbsp)"
                var attr = AttributedString(pillText)
                attr.font = .system(size: UIFont.preferredFont(forTextStyle: .body).pointSize - 1, weight: .medium, design: .monospaced)
                attr.foregroundColor = fileIconColor(for: filename)
                attr.backgroundColor = fileIconColor(for: filename).opacity(0.12)
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
}

private func fileIconChar(for filename: String) -> String {
    let ext = filename.pathExtension.lowercased()
    switch ext {
    case "swift": return "◆"
    case "py": return "◇"
    case "js", "jsx", "ts", "tsx": return "◈"
    case "json", "yaml", "yml", "toml": return "{ }"
    case "md", "txt": return "¶"
    case "html", "xml", "plist": return "◁"
    case "css", "scss", "sass": return "◀"
    case "sh", "bash", "zsh": return "▶"
    case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg": return "□"
    case "pdf": return "▣"
    case "mp4", "mov", "avi", "mkv": return "▷"
    case "mp3", "wav", "m4a", "flac": return "♪"
    case "zip", "tar", "gz", "rar": return "▤"
    default: return "○"
    }
}
