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
}
