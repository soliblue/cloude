import SwiftUI

struct ChatViewMessageListRowMarkdownInline: View {
    let segments: [ChatMarkdownInlineSegment]
    @Environment(\.fontStep) private var fontStep

    var body: some View {
        Text(build())
            .textSelection(.enabled)
    }

    private func build() -> AttributedString {
        let size = ThemeTokens.Text.m + fontStep
        var result = AttributedString()
        for segment in segments {
            switch segment {
            case .text(_, let attr):
                result.append(attr)
            case .code(_, let code):
                var attr = AttributedString(code)
                attr.font = .system(size: size, weight: .regular, design: .monospaced)
                result.append(attr)
            case .filePath(_, let path):
                let filename = (path as NSString).lastPathComponent
                let nbsp = "\u{00A0}"
                let pill = filename.replacingOccurrences(of: " ", with: nbsp)
                var attr = AttributedString(pill)
                attr.font = .system(size: size, weight: .medium, design: .monospaced)
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
}
