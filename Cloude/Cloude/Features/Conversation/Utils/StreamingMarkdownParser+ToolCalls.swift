// StreamingMarkdownParser+ToolCalls.swift

import Foundation
import CloudeShared

extension StreamingMarkdownParser {
    static func parseWithToolCalls(_ text: String, toolCalls: [ToolCall]) -> [StreamingBlock] {
        let topLevelTools = toolCalls
            .filter { $0.parentToolId == nil }
            .sorted { ($0.textPosition ?? 0) < ($1.textPosition ?? 0) }

        guard !topLevelTools.isEmpty else {
            return parse(text)
        }

        let childTools = toolCalls.filter { $0.parentToolId != nil }

        var result: [StreamingBlock] = []
        var currentPosition = 0
        var segmentIndex = 0
        var pendingTools: [ToolCall] = []

        for tool in topLevelTools {
            let toolPosition = tool.textPosition ?? 0

            if toolPosition > currentPosition && toolPosition <= text.count {
                if !pendingTools.isEmpty {
                    let groupWithChildren = includeChildren(parents: pendingTools, allChildren: childTools)
                    result.append(.toolGroup(id: "tools-\(currentPosition)", tools: groupWithChildren))
                    pendingTools = []
                }
                let startIdx = text.index(text.startIndex, offsetBy: currentPosition)
                let endIdx = text.index(text.startIndex, offsetBy: toolPosition)
                let segment = String(text[startIdx..<endIdx])
                if !segment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let prefix = "s\(segmentIndex)-"
                    result.append(contentsOf: parse(segment).map { $0.prefixed(prefix) })
                    segmentIndex += 1
                }
                currentPosition = toolPosition
            }
            pendingTools.append(tool)
        }

        if !pendingTools.isEmpty {
            let groupWithChildren = includeChildren(parents: pendingTools, allChildren: childTools)
            result.append(.toolGroup(id: "tools-\(currentPosition)", tools: groupWithChildren))
        }

        if currentPosition < text.count {
            let startIdx = text.index(text.startIndex, offsetBy: currentPosition)
            let remaining = String(text[startIdx...])
            if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let prefix = "s\(segmentIndex)-"
                result.append(contentsOf: parse(remaining).map { $0.prefixed(prefix) })
            }
        }

        return result
    }

    private static func includeChildren(parents: [ToolCall], allChildren: [ToolCall]) -> [ToolCall] {
        let parentIds = Set(parents.map(\.toolId))
        let matchedChildren = allChildren.filter { parentIds.contains($0.parentToolId ?? "") }
        return parents + matchedChildren
    }
}
