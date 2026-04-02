import SwiftUI

struct StreamingMarkdownView: View {
    let text: String
    var toolCalls: [ToolCall] = []
    var onSelectTool: ((ToolCall, [ToolCall]) -> Void)?
    @State private var frozenBlocks: [StreamingBlock] = []
    @State private var frozenUpTo = ""
    @State private var frozenBlockCount = 0
    @State private var frozenLastId = ""
    @State private var tailBlocks: [StreamingBlock] = []
    @State private var lastText = ""
    @State private var lastToolRevision = ""
    @State private var cachedSplitOffset = 0
    @State private var cachedFenceState = false
    @State private var cachedLastBlankOffset: Int?

    private var toolRevision: String {
        toolCalls.map { "\($0.toolId):\($0.state.rawValue)" }.joined(separator: ",")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FrozenBlocksSection(
                blocks: frozenBlocks,
                blockCount: frozenBlockCount,
                lastBlockId: frozenLastId,
                onSelectTool: onSelectTool
            )
            .equatable()
            ForEach(tailBlocks.map { $0.prefixed("tail-") }, id: \.id) { block in
                StreamingBlockView(block: block, onSelectTool: onSelectTool)
                    .padding(.bottom, DS.Spacing.s)
            }
        }
        .onAppear { updateIncremental() }
        .onChange(of: text) { _, _ in updateIncremental() }
        .onChange(of: toolRevision) { _, _ in updateIncremental() }
    }

    private func updateIncremental() {
        let revision = toolRevision
        if text == lastText && revision == lastToolRevision { return }
        let textChanged = text != lastText
        lastText = text
        lastToolRevision = revision

        if !toolCalls.isEmpty {
            frozenBlocks = []
            frozenUpTo = ""
            frozenBlockCount = 0
            frozenLastId = ""
            cachedSplitOffset = 0
            cachedFenceState = false
            cachedLastBlankOffset = nil
            tailBlocks = StreamingMarkdownParser.parseWithToolCalls(text, toolCalls: toolCalls)
            return
        }

        let splitIndex = textChanged ? stableSplitPointIncremental(in: text) : stableSplitPointIncremental(in: text)

        if let splitIndex {
            let frozenText = String(text[text.startIndex..<splitIndex])
            if frozenText != frozenUpTo {
                frozenBlocks = StreamingMarkdownParser.parse(frozenText)
                frozenUpTo = frozenText
                frozenBlockCount = frozenBlocks.count
                frozenLastId = frozenBlocks.last?.id ?? ""
            }
            tailBlocks = StreamingMarkdownParser.parse(String(text[splitIndex...]))
        } else {
            frozenBlocks = []
            frozenUpTo = ""
            frozenBlockCount = 0
            frozenLastId = ""
            tailBlocks = StreamingMarkdownParser.parse(text)
        }
    }

    private func stableSplitPointIncremental(in text: String) -> String.Index? {
        let utf8 = text.utf8
        if utf8.count <= cachedSplitOffset {
            cachedSplitOffset = 0
            cachedFenceState = false
            cachedLastBlankOffset = nil
            return nil
        }

        let startIndex = utf8.index(utf8.startIndex, offsetBy: cachedSplitOffset)
        var insideFence = cachedFenceState
        var lastBlankIndex: String.Index? = cachedLastBlankOffset.map { utf8.index(utf8.startIndex, offsetBy: $0) }
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

        cachedSplitOffset = utf8.count
        cachedFenceState = insideFence
        cachedLastBlankOffset = lastBlankIndex.map { utf8.distance(from: utf8.startIndex, to: $0) }
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
        VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks, id: \.id) { block in
                StreamingBlockView(block: block, onSelectTool: onSelectTool)
                    .padding(.bottom, DS.Spacing.s)
            }
        }
    }
}
