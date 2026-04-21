import MarkdownUI
import SwiftUI

struct FilePreviewMarkdown: View {
    let data: Data

    var body: some View {
        ScrollView {
            if let text = String(data: data, encoding: .utf8) {
                Markdown(text)
                    .markdownTextStyle { FontSize(ThemeTokens.Text.m) }
                    .padding(ThemeTokens.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else {
                Text("Unable to render markdown")
                    .appFont(size: ThemeTokens.Text.m)
                    .foregroundColor(.secondary)
            }
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.topLeading)
    }
}
