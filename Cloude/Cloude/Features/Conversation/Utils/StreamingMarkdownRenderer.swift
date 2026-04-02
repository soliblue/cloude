import Foundation
import CloudeShared

struct StreamingMarkdownSnapshot {
    var frozenBlocks: [StreamingBlock] = []
    var frozenUpTo = ""
    var frozenBlockCount = 0
    var frozenLastId = ""
    var frozenSignature = ""
    var tailBlocks: [StreamingBlock] = []
}

struct StreamingMarkdownCache {
    var lastText = ""
    var lastToolRevision = 0
    var splitOffset = 0
    var insideFence = false
    var lastBlankOffset: Int?
}

enum StreamingMarkdownRenderer {
    static func toolRevision(for toolCalls: [ToolCall]) -> Int {
        var hasher = Hasher()
        for tool in toolCalls {
            hasher.combine(tool.toolId)
            hasher.combine(tool.state.rawValue)
        }
        return hasher.finalize()
    }

    static func update(
        text: String,
        toolCalls: [ToolCall],
        snapshot: StreamingMarkdownSnapshot,
        cache: StreamingMarkdownCache
    ) -> (snapshot: StreamingMarkdownSnapshot, cache: StreamingMarkdownCache)? {
        let toolRevision = toolRevision(for: toolCalls)
        if text == cache.lastText && toolRevision == cache.lastToolRevision {
            return nil
        }

        var nextSnapshot = snapshot
        var nextCache = cache
        nextCache.lastText = text
        nextCache.lastToolRevision = toolRevision

        let split = stableSplitPointIncremental(in: text, cache: nextCache)
        nextCache.splitOffset = split.cache.splitOffset
        nextCache.insideFence = split.cache.insideFence
        nextCache.lastBlankOffset = split.cache.lastBlankOffset

        if !toolCalls.isEmpty {
            if let splitIndex = split.index {
                let frozenText = String(text[text.startIndex..<splitIndex])
                if frozenText != nextSnapshot.frozenUpTo {
                    nextSnapshot.frozenBlocks = StreamingMarkdownParser.parseWithToolCalls(frozenText, toolCalls: toolCalls)
                    nextSnapshot.frozenUpTo = frozenText
                    nextSnapshot.frozenBlockCount = nextSnapshot.frozenBlocks.count
                    nextSnapshot.frozenLastId = nextSnapshot.frozenBlocks.last?.id ?? ""
                    nextSnapshot.frozenSignature = String(nextSnapshot.frozenBlocks.map(\.renderSignature).hashValue)
                }
                let frozenCharCount = frozenText.count
                let tailText = String(text[splitIndex...])
                let adjustedTools = toolCalls.compactMap { tool -> ToolCall? in
                    if let position = tool.textPosition {
                        if position <= frozenCharCount {
                            return nil
                        }
                        var adjusted = tool
                        adjusted.textPosition = position - frozenCharCount
                        return adjusted
                    }
                    return tool
                }
                nextSnapshot.tailBlocks = StreamingMarkdownParser.parseWithToolCalls(tailText, toolCalls: adjustedTools).map { $0.prefixed("tail-") }
            } else {
                nextSnapshot.frozenBlocks = []
                nextSnapshot.frozenUpTo = ""
                nextSnapshot.frozenBlockCount = 0
                nextSnapshot.frozenLastId = ""
                nextSnapshot.frozenSignature = ""
                nextSnapshot.tailBlocks = StreamingMarkdownParser.parseWithToolCalls(text, toolCalls: toolCalls).map { $0.prefixed("tail-") }
            }
            return (nextSnapshot, nextCache)
        }

        if let splitIndex = split.index {
            let frozenText = String(text[text.startIndex..<splitIndex])
            if frozenText != nextSnapshot.frozenUpTo {
                if !nextSnapshot.frozenUpTo.isEmpty && frozenText.hasPrefix(nextSnapshot.frozenUpTo) {
                    let delta = String(frozenText[frozenText.index(frozenText.startIndex, offsetBy: nextSnapshot.frozenUpTo.count)...])
                    let prefix = "f\(nextSnapshot.frozenBlockCount)-"
                    nextSnapshot.frozenBlocks.append(contentsOf: StreamingMarkdownParser.parse(delta).map { $0.prefixed(prefix) })
                } else {
                    nextSnapshot.frozenBlocks = StreamingMarkdownParser.parse(frozenText)
                }
                nextSnapshot.frozenUpTo = frozenText
                nextSnapshot.frozenBlockCount = nextSnapshot.frozenBlocks.count
                nextSnapshot.frozenLastId = nextSnapshot.frozenBlocks.last?.id ?? ""
                nextSnapshot.frozenSignature = String(nextSnapshot.frozenBlocks.map(\.renderSignature).hashValue)
            }
            nextSnapshot.tailBlocks = StreamingMarkdownParser.parse(String(text[splitIndex...])).map { $0.prefixed("tail-") }
        } else {
            nextSnapshot.frozenBlocks = []
            nextSnapshot.frozenUpTo = ""
            nextSnapshot.frozenBlockCount = 0
            nextSnapshot.frozenLastId = ""
            nextSnapshot.frozenSignature = ""
            nextSnapshot.tailBlocks = StreamingMarkdownParser.parse(text).map { $0.prefixed("tail-") }
        }

        return (nextSnapshot, nextCache)
    }

    private static func stableSplitPointIncremental(in text: String, cache: StreamingMarkdownCache) -> (index: String.Index?, cache: StreamingMarkdownCache) {
        let utf8 = text.utf8
        guard utf8.count > cache.splitOffset else {
            return (nil, StreamingMarkdownCache(lastText: cache.lastText, lastToolRevision: cache.lastToolRevision))
        }

        let startIndex = utf8.index(utf8.startIndex, offsetBy: cache.splitOffset)
        var insideFence = cache.insideFence
        var lastBlankIndex: String.Index? = cache.lastBlankOffset.map { utf8.index(utf8.startIndex, offsetBy: $0) }
        var index = startIndex
        var previousWasBlank = false
        var previousBlankIndex: String.Index?

        while index < utf8.endIndex {
            let lineStart = index
            while index < utf8.endIndex && utf8[index] != UInt8(ascii: "\n") {
                utf8.formIndex(after: &index)
            }
            let lineEnd = index
            if index < utf8.endIndex {
                utf8.formIndex(after: &index)
            }

            let line = text[String.Index(lineStart, within: text)!..<String.Index(lineEnd, within: text)!]
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                insideFence.toggle()
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

        var nextCache = cache
        nextCache.splitOffset = utf8.count
        nextCache.insideFence = insideFence
        nextCache.lastBlankOffset = lastBlankIndex.map { utf8.distance(from: utf8.startIndex, to: $0) }
        return (lastBlankIndex, nextCache)
    }
}
