import SwiftUI

struct FilePreviewXML: View {
    let data: Data

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            if let root = FilePreviewXMLNode.parse(data) {
                FilePreviewXMLRow(node: root)
                    .padding(ThemeTokens.Spacing.m)
                    .frame(minWidth: 0, alignment: .leading)
            } else if let text = String(data: data, encoding: .utf8) {
                Text(text)
                    .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                    .padding(ThemeTokens.Spacing.m)
                    .textSelection(.enabled)
            } else {
                Text("Invalid XML")
                    .appFont(size: ThemeTokens.Text.m)
                    .foregroundColor(.secondary)
            }
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.topLeading)
    }
}
