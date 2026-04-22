import SwiftUI

struct FilePreviewJSON: View {
    let data: Data

    var body: some View {
        FilePreviewScrollContainer(axes: [.vertical, .horizontal]) {
            if let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                FilePreviewJSONRow(key: nil, value: object)
                    .padding(ThemeTokens.Spacing.m)
            } else if let text = String(data: data, encoding: .utf8) {
                Text(text)
                    .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                    .padding(ThemeTokens.Spacing.m)
                    .textSelection(.enabled)
            }
        }
    }
}
