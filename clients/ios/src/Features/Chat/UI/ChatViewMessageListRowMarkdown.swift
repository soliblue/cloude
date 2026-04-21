import MarkdownUI
import SwiftUI

struct ChatViewMessageListRowMarkdown: View {
    let text: String

    var body: some View {
        Markdown(text)
            .markdownTextStyle { FontSize(ThemeTokens.Text.m) }
            .markdownTextStyle(\.code) {
                FontFamilyVariant(.monospaced)
                FontSize(ThemeTokens.Text.m)
            }
            .textSelection(.enabled)
    }
}
