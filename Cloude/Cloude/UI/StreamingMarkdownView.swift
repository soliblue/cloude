// StreamingMarkdownView.swift

import SwiftUI

struct StreamingMarkdownView: View {
    let text: String
    var toolCalls: [ToolCall] = []
    var isComplete: Bool = true
    @State private var frozenBlocks: [StreamingBlock] = []
    @State private var frozenUpTo: String = ""
    @State private var tailBlocks: [StreamingBlock] = []
    @State private var lastText: String = ""
    @State private var lastToolCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(allBlocks.enumerated()), id: \.element.id) { _, block in
                StreamingBlockView(block: block)
                    .padding(.bottom, DS.Spacing.s)
            }
        }
        .onAppear { updateIncremental() }
        .onChange(of: text) { _, _ in updateIncremental() }
        .onChange(of: toolCalls.count) { _, _ in updateIncremental() }
    }

    private var allBlocks: [StreamingBlock] {
        frozenBlocks + tailBlocks.map { $0.prefixed("tail-") }
    }

    private func updateIncremental() {
        if text == lastText && toolCalls.count == lastToolCount { return }
        lastText = text
        lastToolCount = toolCalls.count

        if !toolCalls.isEmpty {
            frozenBlocks = []
            frozenUpTo = ""
            tailBlocks = StreamingMarkdownParser.parseWithToolCalls(text, toolCalls: toolCalls)
            return
        }

        let splitIndex = stableSplitPoint(in: text)

        if let splitIndex {
            let frozenStr = String(text[text.startIndex..<splitIndex])
            if frozenStr != frozenUpTo {
                frozenBlocks = StreamingMarkdownParser.parse(frozenStr)
                frozenUpTo = frozenStr
            }
            let tail = String(text[splitIndex...])
            tailBlocks = StreamingMarkdownParser.parse(tail)
        } else {
            frozenBlocks = []
            frozenUpTo = ""
            tailBlocks = StreamingMarkdownParser.parse(text)
        }
    }

    private func stableSplitPoint(in text: String) -> String.Index? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var insideFence = false
        var lastBlankOutsideFence: Int? = nil

        var prevWasBlank = false
        var prevBlankIndex: Int? = nil

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                insideFence = !insideFence
            }
            if !insideFence && trimmed.isEmpty && i > 0 {
                prevWasBlank = true
                prevBlankIndex = i
            } else if !insideFence && !trimmed.isEmpty && prevWasBlank {
                if let blankIdx = prevBlankIndex {
                    lastBlankOutsideFence = blankIdx
                }
                prevWasBlank = false
            } else {
                prevWasBlank = false
            }
        }

        if let blankLine = lastBlankOutsideFence {
            var offset = 0
            for i in 0...blankLine {
                offset += lines[i].count + 1
            }
            if offset <= text.count {
                return text.index(text.startIndex, offsetBy: offset)
            }
        }
        return nil
    }
}
