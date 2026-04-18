import SwiftUI

struct FilePreviewMarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            if blocks.isEmpty {
                Text(text)
            } else {
                ForEach(blocks, id: \.id) { block in
                    StreamingBlockView(block: block, onSelectTool: nil)
                }
            }
        }
        .font(.system(size: DS.Text.m))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var blocks: [StreamingBlock] {
        StreamingMarkdownParser.parse(text)
    }
}
