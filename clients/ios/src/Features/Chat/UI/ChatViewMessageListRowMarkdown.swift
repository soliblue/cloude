import SwiftUI

struct ChatViewMessageListRowMarkdown: View, Equatable {
    let text: String

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.text == rhs.text }

    var body: some View {
        let _ = PerfCounters.bump("mdrow.body")
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            ForEach(ChatMarkdownParser.parse(text), id: \.id) { block in
                ChatViewMessageListRowMarkdownBlock(block: block)
            }
        }
        .appFont(size: ThemeTokens.Text.m)
    }
}
