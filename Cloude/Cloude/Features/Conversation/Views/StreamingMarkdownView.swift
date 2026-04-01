import SwiftUI

struct StreamingMarkdownView: View {
    let text: String
    var toolCalls: [ToolCall] = []
    var onSelectTool: ((ToolCall, [ToolCall]) -> Void)?
    @State private var snapshot = StreamingMarkdownSnapshot()
    @State private var cache = StreamingMarkdownCache()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FrozenBlocksSection(
                blocks: snapshot.frozenBlocks,
                blockCount: snapshot.frozenBlockCount,
                lastBlockId: snapshot.frozenLastId,
                signature: snapshot.frozenSignature,
                onSelectTool: onSelectTool
            )
                .equatable()
            ForEach(snapshot.tailBlocks, id: \.id) { block in
                StreamingBlockView(block: block, onSelectTool: onSelectTool)
                    .padding(.bottom, DS.Spacing.s)
            }
        }
        .onAppear { updateState() }
        .onChange(of: text) { _, _ in updateState() }
        .onChange(of: StreamingMarkdownRenderer.toolRevision(for: toolCalls)) { _, _ in updateState() }
    }

    private func updateState() {
        if let updated = StreamingMarkdownRenderer.update(text: text, toolCalls: toolCalls, snapshot: snapshot, cache: cache) {
            snapshot = updated.snapshot
            cache = updated.cache
        }
    }
}

private struct FrozenBlocksSection: View, Equatable {
    let blocks: [StreamingBlock]
    let blockCount: Int
    let lastBlockId: String
    let signature: String
    var onSelectTool: ((ToolCall, [ToolCall]) -> Void)?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.blockCount == rhs.blockCount && lhs.lastBlockId == rhs.lastBlockId && lhs.signature == rhs.signature
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks, id: \.id) { block in
                StreamingBlockView(block: block, onSelectTool: onSelectTool)
                    .padding(.bottom, DS.Spacing.s)
            }
        }
    }
}
