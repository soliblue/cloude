import SwiftUI

struct ChatViewMessageListRowStreamingMarkdown: View {
    let text: String
    @State private var frozen = FrozenState()
    @State private var tailBlocks: [ChatMarkdownBlock] = []
    @State private var lastText = ""
    @State private var splitCache = SplitCache()

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

        if let splitIndex = stableSplitPointIncremental(in: text) {
            let frozenText = String(text[text.startIndex..<splitIndex])
            if frozenText != frozen.upTo {
                frozen.blocks = ChatMarkdownParser.parse(frozenText)
                frozen.upTo = frozenText
            }
            let frozenLineCount = frozenText.components(separatedBy: "\n").count - 1
            tailBlocks = ChatMarkdownParser.parse(
                String(text[splitIndex...]), lineOffset: frozenLineCount)
        } else {
            PerfCounters.bump("str.splitReset")
            frozen.reset()
            tailBlocks = ChatMarkdownParser.parse(text)
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
        var lastBlankIndex: String.Index? = splitCache.lastBlankOffset.map {
            utf8.index(utf8.startIndex, offsetBy: $0)
        }
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

            let line = text[
                String.Index(lineStart, within: text)!..<String.Index(lineEnd, within: text)!]
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
        splitCache.lastBlankOffset = lastBlankIndex.map {
            utf8.distance(from: utf8.startIndex, to: $0)
        }
        return lastBlankIndex
    }
}

private struct FrozenState {
    var blocks: [ChatMarkdownBlock] = []
    var upTo = ""

    mutating func reset() {
        blocks = []
        upTo = ""
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
