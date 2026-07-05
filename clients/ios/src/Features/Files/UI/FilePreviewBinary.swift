import SwiftUI

struct FilePreviewBinary: View {
    let node: FileNodeDTO

    var body: some View {
        VStack(spacing: ThemeTokens.Spacing.m) {
            Image(systemName: "doc")
                .appFont(size: ThemeTokens.Icon.l)
                .foregroundColor(ThemeColor.secondary)
            Text(node.name)
                .appFont(size: ThemeTokens.Text.m)
            if let size = node.size {
                Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                    .appFont(size: ThemeTokens.Text.s)
                    .foregroundColor(ThemeColor.secondary)
            }
            Text("Preview not available")
                .appFont(size: ThemeTokens.Text.s)
                .foregroundColor(ThemeColor.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
