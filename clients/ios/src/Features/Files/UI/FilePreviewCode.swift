import HighlightSwift
import SwiftUI

struct FilePreviewCode: View {
    let data: Data
    let language: String
    let wrap: Bool

    var body: some View {
        FilePreviewScrollContainer(axes: wrap ? [.vertical] : [.vertical, .horizontal]) {
            if let text = String(data: data, encoding: .utf8) {
                CodeText(text)
                    .highlightLanguage(highlightLanguage)
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                    .padding(ThemeTokens.Spacing.m)
                    .textSelection(.enabled)
            } else {
                Text("Unable to decode")
                    .appFont(size: ThemeTokens.Text.m)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var highlightLanguage: HighlightLanguage {
        switch language {
        case "bash": return .bash
        case "cpp": return .cPlusPlus
        case "csharp": return .cSharp
        case "javascript", "jsx": return .javaScript
        case "plaintext": return .plaintext
        case "typescript", "tsx": return .typeScript
        default: return HighlightLanguage(rawValue: language) ?? .plaintext
        }
    }
}
