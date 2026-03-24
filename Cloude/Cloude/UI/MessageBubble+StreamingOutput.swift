// MessageBubble+StreamingOutput.swift

import SwiftUI

struct StreamingOutput: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if text.isEmpty {
                StreamingPlaceholder()
            }

            if !text.isEmpty {
                StreamingMarkdownView(text: text, isComplete: false)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct StreamingInterleavedOutput: View {
    let text: String
    let toolCalls: [ToolCall]
    var runStats: (durationMs: Int, costUsd: Double, model: String?)? = nil

    private var groupedSegments: [StreamingSegment] {
        let topLevelTools = toolCalls
            .filter { $0.parentToolId == nil }
            .sorted { ($0.textPosition ?? 0) < ($1.textPosition ?? 0) }

        var result: [StreamingSegment] = []
        var currentIndex = 0
        var pendingTools: [ToolCall] = []

        for tool in topLevelTools {
            let position = tool.textPosition ?? 0
            if position > currentIndex && position <= text.count {
                if !pendingTools.isEmpty {
                    result.append(.tools(pendingTools))
                    pendingTools = []
                }
                let startIdx = text.index(text.startIndex, offsetBy: currentIndex)
                let endIdx = text.index(text.startIndex, offsetBy: position)
                let segment = String(text[startIdx..<endIdx])
                if !segment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(.text(segment))
                }
                currentIndex = position
            }
            pendingTools.append(tool)
        }

        if !pendingTools.isEmpty {
            result.append(.tools(pendingTools))
        }

        if currentIndex < text.count {
            let startIdx = text.index(text.startIndex, offsetBy: currentIndex)
            let remaining = String(text[startIdx...])
            if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(.text(remaining))
            }
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if text.isEmpty && toolCalls.isEmpty && runStats == nil {
                StreamingPlaceholder()
            }

            VStack(alignment: .leading, spacing: 4) {
                if !groupedSegments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(groupedSegments.enumerated()), id: \.offset) { _, segment in
                            switch segment {
                            case .text(let content):
                                StreamingMarkdownView(text: content, isComplete: false)
                            case .tools(let tools):
                                let allChildren = toolCalls.filter { $0.parentToolId != nil }
                                let widgetTools = tools.filter { WidgetRegistry.isWidget($0.name) }
                                let regularTools = tools.filter { !WidgetRegistry.isWidget($0.name) }

                                ForEach(widgetTools, id: \.toolId) { tool in
                                    WidgetRegistry.view(for: tool.name, input: tool.input)
                                }

                                if !regularTools.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(regularTools.reversed(), id: \.toolId) { tool in
                                                InlineToolPill(
                                                    toolCall: tool,
                                                    children: allChildren.filter { $0.parentToolId == tool.toolId }
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                    .padding(.horizontal, -16)
                                    .scrollClipDisabled()
                                }
                            }
                        }
                    }
                }

                if let stats = runStats {
                    HStack(spacing: 5) {
                        Text(Date(), style: .time)
                            .font(.caption2)
                        RunStatsView(durationMs: stats.durationMs, costUsd: stats.costUsd, model: stats.model)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private enum StreamingSegment {
    case text(String)
    case tools([ToolCall])
}

struct StreamingPlaceholder: View {
    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Claude is responding...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
