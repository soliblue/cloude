import SwiftUI

struct ChatViewMessageListRowMarkdownBlock: View {
    let block: ChatMarkdownBlock

    var body: some View {
        switch block {
        case .text(_, let attributed, let segments):
            if segments.contains(where: \.isSpecial) {
                ChatViewMessageListRowMarkdownInline(segments: segments)
            } else {
                Text(attributed)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .code(_, let content, let language, _):
            ChatViewMessageListRowMarkdownBlockCode(code: content, language: language)
        case .table(_, let rows):
            ChatViewMessageListRowMarkdownBlockTable(rows: rows)
        case .blockquote(_, let content):
            ChatViewMessageListRowMarkdownBlockQuote(text: content)
        case .horizontalRule:
            ChatViewMessageListRowMarkdownBlockRule()
        case .header(_, _, let content, let segments):
            if segments.contains(where: \.isSpecial) {
                ChatViewMessageListRowMarkdownInline(segments: segments)
            } else {
                Text(content)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
