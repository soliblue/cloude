import SwiftUI
import UIKit
import CloudeShared

enum InlineSegment: Identifiable, Equatable {
    case text(id: UUID = UUID(), AttributedString)
    case code(id: UUID = UUID(), String)
    case filePath(id: UUID = UUID(), String)
    case url(id: UUID = UUID(), String, String)
    case lineBreak(id: UUID = UUID())

    var id: UUID {
        switch self {
        case .text(let id, _): return id
        case .code(let id, _): return id
        case .filePath(let id, _): return id
        case .url(let id, _, _): return id
        case .lineBreak(let id): return id
        }
    }
}

struct InlineTextView: View {
    let segments: [InlineSegment]

    var body: some View {
        SelectableTextView(
            attributedString: buildNSAttributedString(),
            onLinkTap: { url in
                UIApplication.shared.open(url)
            }
        )
    }

    private func buildNSAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodySize = UIFont.preferredFont(forTextStyle: .body).pointSize
        let bodyFont = UIFont.systemFont(ofSize: bodySize)
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: UIColor.label
        ]

        for segment in segments {
            switch segment {
            case .text(_, let attr):
                let converted: NSAttributedString = NSAttributedString(attr)
                let nsAttr = NSMutableAttributedString(attributedString: converted)
                let fullRange = NSRange(location: 0, length: nsAttr.length)
                nsAttr.enumerateAttribute(NSAttributedString.Key.font, in: fullRange) { value, range, _ in
                    if value == nil {
                        nsAttr.addAttribute(NSAttributedString.Key.font, value: bodyFont, range: range)
                    }
                }
                nsAttr.enumerateAttribute(NSAttributedString.Key.foregroundColor, in: fullRange) { value, range, _ in
                    if value == nil {
                        nsAttr.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.label, range: range)
                    }
                }
                result.append(nsAttr)
            case .code(_, let code):
                let monoFont = UIFont.monospacedSystemFont(ofSize: bodySize - 1, weight: .regular)
                let attr = NSAttributedString(string: code, attributes: [
                    .font: monoFont,
                    .foregroundColor: UIColor.label,
                    .backgroundColor: UIColor.secondarySystemFill
                ])
                result.append(attr)
            case .filePath(_, let path):
                let filename = path.lastPathComponent
                let icon = fileIconChar(for: filename)
                let nbsp = "\u{00A0}"
                let pillText = "\(nbsp)\(icon)\(nbsp)\(filename.replacingOccurrences(of: " ", with: nbsp))\(nbsp)"
                let color = UIColor(fileIconColor(for: filename))
                var attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: bodySize - 1, weight: .medium),
                    .foregroundColor: color,
                    .backgroundColor: color.withAlphaComponent(0.12)
                ]
                if let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   let url = URL(string: "cloude://file\(encodedPath)") {
                    attrs[.link] = url
                }
                result.append(NSAttributedString(string: pillText, attributes: attrs))
            case .url(_, let urlString, let displayText):
                let nbsp = "\u{00A0}"
                let pillText = "\(nbsp)↗\(nbsp)\(displayText.replacingOccurrences(of: " ", with: nbsp))\(nbsp)"
                var attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: bodySize - 1, weight: .medium),
                    .foregroundColor: UIColor.systemBlue,
                    .backgroundColor: UIColor.systemBlue.withAlphaComponent(0.12)
                ]
                if let url = URL(string: urlString) {
                    attrs[.link] = url
                }
                result.append(NSAttributedString(string: pillText, attributes: attrs))
            case .lineBreak:
                result.append(NSAttributedString(string: "\n", attributes: defaultAttributes))
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
