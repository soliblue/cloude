import SwiftUI

struct ChatViewMessageListRowStreamingMarkdown: View {
    let text: String
    @State private var frozen = FrozenState()
    @State private var tailBlocks: [ChatMarkdownBlock] = []
    @State private var lastText = ""
    @State private var lastBlockSignature: [String] = []

    var body: some View {
        let _ = PerfCounters.bump("str.body")
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            if !frozen.blocks.isEmpty {
                ChatViewMessageListRowStreamingMarkdownFrozen(blocks: frozen.blocks)
                    .equatable()
            }
            ForEach(tailBlocks, id: \.id) { block in
                ChatViewMessageListRowMarkdownBlock(block: block)
            }
        }
        .appFont(size: ThemeTokens.Text.m)
        .onAppear { updateIncremental() }
        .onChange(of: text) { _, _ in updateIncremental() }
    }

    private func updateIncremental() {
        if text == lastText { return }
        lastText = text
        let blocks = ChatMarkdownParser.parse(text)
        frozen.blocks = Array(blocks.dropLast())
        tailBlocks = Array(blocks.suffix(1))
        diffBlockSignature()
    }

    private func diffBlockSignature() {
        let combined = frozen.blocks + tailBlocks
        let signature = combined.map { "\(Self.kind(of: $0)):\($0.id)" }
        if signature.isEmpty { return }
        if lastBlockSignature.isEmpty {
            lastBlockSignature = signature
            return
        }
        let old = lastBlockSignature
        let oldIds = Set(old)
        let newIds = Set(signature)
        let added = signature.filter { !oldIds.contains($0) }
        let removed = old.filter { !newIds.contains($0) }
        if added.isEmpty && removed.isEmpty {
            lastBlockSignature = signature
            return
        }
        let reused = signature.filter { oldIds.contains($0) }.count
        PerfCounters.bump("str.blockChurn")
        PerfCounters.event(
            "block diff added=\(added.count) removed=\(removed.count) reused=\(reused) "
                + "addedList=[\(added.joined(separator: ","))] "
                + "removedList=[\(removed.joined(separator: ","))]"
        )
        lastBlockSignature = signature
    }

    private static func kind(of block: ChatMarkdownBlock) -> String {
        switch block {
        case .text: return "text"
        case .code: return "code"
        case .table: return "table"
        case .blockquote: return "quote"
        case .horizontalRule: return "hr"
        case .header: return "header"
        }
    }
}

private struct FrozenState {
    var blocks: [ChatMarkdownBlock] = []
}
