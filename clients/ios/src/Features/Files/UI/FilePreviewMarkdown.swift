import MarkdownUI
import SwiftUI

struct FilePreviewMarkdown: View {
    let data: Data

    var body: some View {
        FilePreviewScrollContainer(axes: .vertical) {
            if let text = String(data: data, encoding: .utf8) {
                Markdown(text)
                    .markdownTextStyle { FontSize(ThemeTokens.Text.m) }
                    .padding(ThemeTokens.Spacing.m)
                    .textSelection(.enabled)
            } else {
                Text("Unable to render markdown")
                    .appFont(size: ThemeTokens.Text.m)
                    .foregroundColor(.secondary)
            }
        }
    }
}
