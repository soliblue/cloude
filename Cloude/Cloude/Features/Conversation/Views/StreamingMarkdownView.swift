import SwiftUI

private struct FrozenState {
    var blocks: [StreamingBlock] = []
    var upTo = ""
    var blockCount = 0
    var lastId = ""

    mutating func reset() {
        blocks = []
        upTo = ""
        blockCount = 0
        lastId = ""
    }
}

private struct SplitCache {
    var offset = 0
    var insideFence = false
    var lastBlankOffset: Int?

    mutating func reset() {
        offset = 0
        insideFence = false
        lastBlankOffset = nil
    }
}

struct StreamingMarkdownView: View {
    let text: String
    var toolCalls: [ToolCall] = []
    var onSelectTool: ((ToolCall, [ToolCall]) -> Void)?
    @State private var frozen = FrozenState()
    @State private var tailBlocks: [StreamingBlock] = []
    @State private var lastText = ""
    @State private var lastToolRevision = 0
    @State private var splitCache = SplitCache()

    private var toolRevision: Int {
        var hasher = Hasher()
        for call in toolCalls {
            hasher.combine(call.toolId)
            hasher.combine(call.state.rawValue)
        }
        return hasher.finalize()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            if !frozen.blocks.isEmpty {
                FrozenBlocksSection(
                    blocks: frozen.blocks,
                    blockCount: frozen.blockCount,
                    lastBlockId: frozen.lastId,
                    onSelectTool: onSelectTool
                )
                .equatable()
            }
            ForEach(tailBlocks, id: \.id) { block in
                StreamingBlockView(block: block, onSelectTool: onSelectTool)
            }
        }
        .animation(.easeOut(duration: 0.6), value: text)
        .onAppear { updateIncremental() }
        .onChange(of: text) { _, _ in updateIncremental() }
        .onChange(of: toolRevision) { _, _ in updateIncremental() }
    }

    private func updateIncremental() {
        let revision = toolRevision
        if text == lastText && revision == lastToolRevision { return }
        lastText = text
        lastToolRevision = revision

        if !toolCalls.isEmpty {
            frozen.reset()
            splitCache.reset()
            tailBlocks = StreamingMarkdownParser.parseWithToolCalls(text, toolCalls: toolCalls).map { $0.prefixed("tail-") }
            return
        }

        if let splitIndex = stableSplitPointIncremental(in: text) {
            let frozenText = String(text[text.startIndex..<splitIndex])
            if frozenText != frozen.upTo {
                frozen.blocks = StreamingMarkdownParser.parse(frozenText)
                frozen.upTo = frozenText
                frozen.blockCount = frozen.blocks.count
                frozen.lastId = frozen.blocks.last?.id ?? ""
            }
            tailBlocks = StreamingMarkdownParser.parse(String(text[splitIndex...])).map { $0.prefixed("tail-") }
        } else {
            frozen.reset()
            tailBlocks = StreamingMarkdownParser.parse(text).map { $0.prefixed("tail-") }
        }
    }

    private func stableSplitPointIncremental(in text: String) -> String.Index? {
        let utf8 = text.utf8
        if utf8.count <= splitCache.offset {
            splitCache.reset()
            return nil
        }

        let startIndex = utf8.index(utf8.startIndex, offsetBy: splitCache.offset)
        var insideFence = splitCache.insideFence
        var lastBlankIndex: String.Index? = splitCache.lastBlankOffset.map { utf8.index(utf8.startIndex, offsetBy: $0) }
        var index = startIndex
        var previousWasBlank = false
        var previousBlankIndex: String.Index?

        while index < utf8.endIndex {
            let lineStart = index
            while index < utf8.endIndex && utf8[index] != UInt8(ascii: "\n") {
                utf8.formIndex(after: &index)
            }
            let lineEnd = index
            if index < utf8.endIndex { utf8.formIndex(after: &index) }

            let line = text[String.Index(lineStart, within: text)!..<String.Index(lineEnd, within: text)!]
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                insideFence = !insideFence
            }
            if !insideFence && trimmed.isEmpty && lineStart > utf8.startIndex {
                previousWasBlank = true
                previousBlankIndex = index
            } else if !insideFence && !trimmed.isEmpty && previousWasBlank {
                if let previousBlankIndex {
                    lastBlankIndex = previousBlankIndex
                }
                previousWasBlank = false
            } else {
                previousWasBlank = false
            }
        }

        splitCache.offset = utf8.count
        splitCache.insideFence = insideFence
        splitCache.lastBlankOffset = lastBlankIndex.map { utf8.distance(from: utf8.startIndex, to: $0) }
        return lastBlankIndex
    }
}

private struct FrozenBlocksSection: View, Equatable {
    let blocks: [StreamingBlock]
    let blockCount: Int
    let lastBlockId: String
    var onSelectTool: ((ToolCall, [ToolCall]) -> Void)?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.blockCount == rhs.blockCount && lhs.lastBlockId == rhs.lastBlockId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            ForEach(blocks, id: \.id) { block in
                StreamingBlockView(block: block, onSelectTool: onSelectTool)
            }
        }
    }
}
