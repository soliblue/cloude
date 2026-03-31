// StreamingMarkdownView.swift

import SwiftUI

struct StreamingMarkdownView: View {
    let text: String
    var toolCalls: [ToolCall] = []
    var isComplete: Bool = true
    var onSelectTool: ((ToolCall, [ToolCall]) -> Void)?
    @State private var frozenBlocks: [StreamingBlock] = []
    @State private var frozenUpTo: String = ""
    @State private var frozenBlockCount: Int = 0
    @State private var frozenLastId: String = ""
    @State private var tailBlocks: [StreamingBlock] = []
    @State private var lastText: String = ""
    @State private var lastToolRevision: String = ""
    @State private var cachedSplitOffset: Int = 0
    @State private var cachedFenceState: Bool = false
    @State private var cachedLastBlankOffset: Int? = nil

    private var toolRevision: String {
        toolCalls.map { "\($0.toolId):\($0.state.rawValue)" }.joined(separator: ",")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FrozenBlocksSection(blocks: frozenBlocks, blockCount: frozenBlockCount, lastBlockId: frozenLastId)
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
        let rev = toolRevision
        if text == lastText && rev == lastToolRevision { return }
        let textChanged = text != lastText
        lastText = text
        lastToolRevision = rev

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
            let frozenStr = String(text[text.startIndex..<splitIndex])
            if frozenStr != frozenUpTo {
                frozenBlocks = StreamingMarkdownParser.parse(frozenStr)
                frozenUpTo = frozenStr
                frozenBlockCount = frozenBlocks.count
                frozenLastId = frozenBlocks.last?.id ?? ""
            }
            let tail = String(text[splitIndex...])
            tailBlocks = StreamingMarkdownParser.parse(tail)
        } else {
            frozenBlocks = []
            frozenUpTo = ""
            frozenBlockCount = 0
            frozenLastId = ""
            tailBlocks = StreamingMarkdownParser.parse(text)
        }
    }

    private func stableSplitPointIncremental(in text: String) -> String.Index? {
        guard text.count > cachedSplitOffset else {
            cachedSplitOffset = 0
            cachedFenceState = false
            cachedLastBlankOffset = nil
            return nil
        }

        let startOffset = cachedSplitOffset
        var insideFence = cachedFenceState
        var lastBlankOffset = cachedLastBlankOffset

        var i = startOffset
        var prevWasBlank = false
        var prevBlankOffset: Int? = nil

        while i < text.count {
            let lineStart = i
            while i < text.count && text[text.index(text.startIndex, offsetBy: i)] != "\n" {
                i += 1
            }
            let lineEnd = i
            if i < text.count { i += 1 }

            let lineStartIdx = text.index(text.startIndex, offsetBy: lineStart)
            let lineEndIdx = text.index(text.startIndex, offsetBy: lineEnd)
            let line = text[lineStartIdx..<lineEndIdx]
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                insideFence = !insideFence
            }
            if !insideFence && trimmed.isEmpty && lineStart > 0 {
                prevWasBlank = true
                prevBlankOffset = i
            } else if !insideFence && !trimmed.isEmpty && prevWasBlank {
                if let blankOff = prevBlankOffset {
                    lastBlankOffset = blankOff
                }
                prevWasBlank = false
            } else {
                prevWasBlank = false
            }
        }

        cachedSplitOffset = text.count
        cachedFenceState = insideFence
        cachedLastBlankOffset = lastBlankOffset

        if let offset = lastBlankOffset, offset <= text.count {
            return text.index(text.startIndex, offsetBy: offset)
        }
        return nil
    }
}

private struct FrozenBlocksSection: View, Equatable {
    let blocks: [StreamingBlock]
    let blockCount: Int
    let lastBlockId: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.blockCount == rhs.blockCount && lhs.lastBlockId == rhs.lastBlockId
    }

    var body: some View {
        ForEach(blocks, id: \.id) { block in
            StreamingBlockView(block: block)
                .padding(.bottom, DS.Spacing.s)
        }
    }
}
