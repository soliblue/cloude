import HighlightSwift
import SwiftUI

struct FilePreviewCode: View {
    let data: Data
    let language: String
    let wrap: Bool

    var body: some View {
        FilePreviewScrollContainer(axes: wrap ? [.vertical] : [.vertical, .horizontal]) {
            if data.count > 65_536 {
                FilePreviewPlainText(data: data)
            } else {
                CodeText(String(decoding: data, as: UTF8.self))
                    .highlightLanguage(HighlightLanguageResolver.resolve(language))
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                    .padding(ThemeTokens.Spacing.m)
                    .textSelection(.enabled)
            }
        }
    }
}
