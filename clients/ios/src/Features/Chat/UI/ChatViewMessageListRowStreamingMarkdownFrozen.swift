import SwiftUI

struct ChatViewMessageListRowStreamingMarkdownFrozen: View, Equatable {
    let blocks: [ChatMarkdownBlock]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.blocks.count == rhs.blocks.count && lhs.blocks.last?.id == rhs.blocks.last?.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            ForEach(blocks, id: \.id) { block in
                ChatViewMessageListRowMarkdownBlock(block: block)
            }
        }
    }
}
