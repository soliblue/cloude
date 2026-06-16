import SwiftUI

struct FilePreviewJSON: View {
    let object: Any?
    let text: String?

    init(data: Data) {
        object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        text = String(data: data, encoding: .utf8)
    }

    var body: some View {
        FilePreviewScrollContainer(axes: [.vertical, .horizontal]) {
            if let object {
                FilePreviewJSONRow(key: nil, value: object)
                    .padding(ThemeTokens.Spacing.m)
            } else if let text {
                Text(text)
                    .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                    .padding(ThemeTokens.Spacing.m)
                    .textSelection(.enabled)
            }
        }
    }
}
