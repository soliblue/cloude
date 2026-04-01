// StreamingMarkdownView.swift

import SwiftUI

struct StreamingMarkdownView: View {
    let text: String
    var toolCalls: [ToolCall] = []
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
            ForEach(tailBlocks, id: \.id) { block in
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
        lastText = text
        lastToolRevision = rev

        if !toolCalls.isEmpty {
            let splitIndex = stableSplitPointIncremental(in: text)
            if let splitIndex {
                let frozenStr = String(text[text.startIndex..<splitIndex])
                if frozenStr != frozenUpTo {
                    frozenBlocks = StreamingMarkdownParser.parseWithToolCalls(frozenStr, toolCalls: toolCalls)
                    frozenUpTo = frozenStr
                    frozenBlockCount = frozenBlocks.count
                    frozenLastId = frozenBlocks.last?.id ?? ""
                }
                let frozenCharCount = frozenStr.count
                let tailStr = String(text[splitIndex...])
                let adjustedTools = toolCalls.map { tool -> ToolCall in
                    var t = tool
                    if let pos = t.textPosition { t.textPosition = pos - frozenCharCount }
                    return t
                }
                tailBlocks = StreamingMarkdownParser.parseWithToolCalls(tailStr, toolCalls: adjustedTools).map { $0.prefixed("tail-") }
            } else {
                frozenBlocks = []
                frozenUpTo = ""
                frozenBlockCount = 0
                frozenLastId = ""
                tailBlocks = StreamingMarkdownParser.parseWithToolCalls(text, toolCalls: toolCalls).map { $0.prefixed("tail-") }
            }
            return
        }

        let splitIndex = stableSplitPointIncremental(in: text)

        if let splitIndex {
            let frozenStr = String(text[text.startIndex..<splitIndex])
            if frozenStr != frozenUpTo {
                if !frozenUpTo.isEmpty && frozenStr.hasPrefix(frozenUpTo) {
                    let delta = String(frozenStr[frozenStr.index(frozenStr.startIndex, offsetBy: frozenUpTo.count)...])
                    frozenBlocks.append(contentsOf: StreamingMarkdownParser.parse(delta))
                } else {
                    frozenBlocks = StreamingMarkdownParser.parse(frozenStr)
                }
                frozenUpTo = frozenStr
                frozenBlockCount = frozenBlocks.count
                frozenLastId = frozenBlocks.last?.id ?? ""
            }
            let tail = String(text[splitIndex...])
            tailBlocks = StreamingMarkdownParser.parse(tail).map { $0.prefixed("tail-") }
        } else {
            frozenBlocks = []
            frozenUpTo = ""
            frozenBlockCount = 0
            frozenLastId = ""
            tailBlocks = StreamingMarkdownParser.parse(text).map { $0.prefixed("tail-") }
        }
    }

    private func stableSplitPointIncremental(in text: String) -> String.Index? {
        let utf8 = text.utf8
        guard utf8.count > cachedSplitOffset else {
            cachedSplitOffset = 0
            cachedFenceState = false
            cachedLastBlankOffset = nil
            return nil
        }

        let startIdx = utf8.index(utf8.startIndex, offsetBy: cachedSplitOffset)
        var insideFence = cachedFenceState
        var lastBlankIdx: String.Index? = cachedLastBlankOffset.map { utf8.index(utf8.startIndex, offsetBy: $0) }

        var idx = startIdx
        var prevWasBlank = false
        var prevBlankIdx: String.Index? = nil

        while idx < utf8.endIndex {
            let lineStart = idx
            while idx < utf8.endIndex && utf8[idx] != UInt8(ascii: "\n") {
                utf8.formIndex(after: &idx)
            }
            let lineEnd = idx
            if idx < utf8.endIndex { utf8.formIndex(after: &idx) }

            let line = text[String.Index(lineStart, within: text)!..<String.Index(lineEnd, within: text)!]
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                insideFence = !insideFence
            }
            if !insideFence && trimmed.isEmpty && lineStart > utf8.startIndex {
                prevWasBlank = true
                prevBlankIdx = idx
            } else if !insideFence && !trimmed.isEmpty && prevWasBlank {
                if let blankIdx = prevBlankIdx {
                    lastBlankIdx = blankIdx
                }
                prevWasBlank = false
            } else {
                prevWasBlank = false
            }
        }

        cachedSplitOffset = utf8.count
        cachedFenceState = insideFence
        cachedLastBlankOffset = lastBlankIdx.map { utf8.distance(from: utf8.startIndex, to: $0) }

        return lastBlankIdx
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
        VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks, id: \.id) { block in
                StreamingBlockView(block: block)
                    .padding(.bottom, DS.Spacing.s)
            }
        }
    }
}
