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

    var isSpecial: Bool {
        switch self {
        case .code, .filePath: return true
        case .text, .lineBreak: return false
        }
    }
}

struct InlineTextView: View {
    let segments: [InlineSegment]

    var body: some View {
        Text(buildAttributedString())
    }

    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()
        for segment in segments {
            switch segment {
            case .text(_, let attr):
                result.append(attr)
            case .code(_, let code):
                var attr = AttributedString(code)
                attr.font = .system(size: DS.Text.m, weight: .regular, design: .monospaced)
                result.append(attr)
            case .filePath(_, let path):
                let filename = path.lastPathComponent
                let nbsp = "\u{00A0}"
                let pillText = filename.replacingOccurrences(of: " ", with: nbsp)
                var attr = AttributedString(pillText)
                attr.font = .system(size: DS.Text.m, weight: .medium, design: .monospaced)
                attr.foregroundColor = fileIconColor(for: filename)
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
