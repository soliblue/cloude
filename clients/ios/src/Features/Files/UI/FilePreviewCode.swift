import HighlightSwift
import SwiftUI

struct FilePreviewCode: View {
    let data: Data
    let language: String
    let wrap: Bool

    var body: some View {
        ScrollView(wrap ? [.vertical] : [.vertical, .horizontal]) {
            if let text = String(data: data, encoding: .utf8) {
                CodeText(text)
                    .font(.system(size: ThemeTokens.Text.m, design: .monospaced))
                    .padding(ThemeTokens.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            } else {
                Text("Unable to decode")
                    .appFont(size: ThemeTokens.Text.m)
                    .foregroundColor(.secondary)
            }
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.topLeading)
    }
}
