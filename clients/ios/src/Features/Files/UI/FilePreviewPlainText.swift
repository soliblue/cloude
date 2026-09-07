import SwiftUI

struct FilePreviewPlainText: View {
    let data: Data
    @State private var chunks: [String] = []

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(chunks.indices, id: \.self) { index in
                Text(chunks[index])
                    .textSelection(.enabled)
            }
        }
        .appFont(size: ThemeTokens.Text.s, design: .monospaced)
        .padding(ThemeTokens.Spacing.m)
        .task(id: data) { chunks = await FilePreviewTextService.chunks(data) }
    }
}
