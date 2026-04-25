import SwiftUI

struct ChatViewMessageListRowStreamingMarkdown: View {
    let text: String
    @State private var frozen = FrozenState()
    @State private var tailBlocks: [ChatMarkdownBlock] = []
    @State private var lastText = ""
    @State private var splitCache = SplitCache()
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

        if let splitIndex = stableSplitPointIncremental(in: text) {
            let frozenText = String(text[text.startIndex..<splitIndex])
            if frozenText != frozen.upTo {
                frozen.blocks = ChatMarkdownParser.parse(frozenText)
                frozen.upTo = frozenText
            }
            let frozenLineCount = frozenText.components(separatedBy: "\n").count - 1
            tailBlocks = Self.stabilizeTailIds(
                ChatMarkdownParser.parse(
                    String(text[splitIndex...]), lineOffset: frozenLineCount),
                previous: tailBlocks)
        } else {
            PerfCounters.bump("str.splitReset")
            frozen.reset()
            tailBlocks = Self.stabilizeTailIds(
                ChatMarkdownParser.parse(text), previous: tailBlocks)
        }
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

    private static func stabilizeTailIds(
        _ blocks: [ChatMarkdownBlock], previous: [ChatMarkdownBlock]
    ) -> [ChatMarkdownBlock] {
        var counts: [String: Int] = [:]
        return blocks.enumerated().map { offset, block in
            let sig = block.contentSignature
            let n = counts[sig, default: 0]
            counts[sig] = n + 1
            if offset < previous.count,
                kind(of: previous[offset]) == kind(of: block),
                previous[offset].id.hasPrefix("tail-")
            {
                let prevSig = previous[offset].contentSignature
                if sig.hasPrefix(prevSig) || prevSig.hasPrefix(sig) {
                    return block.withId(previous[offset].id)
                }
            }
            return block.withId("tail-\(sig)#\(n)")
        }
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
