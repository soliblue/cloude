import SwiftUI
import Foundation

struct StatLabel: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2)
    }
}

struct StreamingOutput: View {
    let text: String
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if text.isEmpty {
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

            if !text.isEmpty {
                StreamingMarkdownView(text: text, isComplete: false)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(
            Color.accentColor
                .opacity(pulse ? 0.06 : 0.02)
        )
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

struct StreamingInterleavedOutput: View {
    let text: String
    let toolCalls: [ToolCall]
    var runStats: (durationMs: Int, costUsd: Double)? = nil
    @State private var pulse = false

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

            VStack(alignment: .leading, spacing: 4) {
                if !groupedSegments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(groupedSegments.enumerated()), id: \.offset) { _, segment in
                            switch segment {
                            case .text(let content):
                                StreamingMarkdownView(text: content, isComplete: false)
                            case .tools(let tools):
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(tools.reversed().enumerated()), id: \.offset) { _, tool in
                                            InlineToolPill(toolCall: tool)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                                .padding(.horizontal, -16)
                            }
                        }
                    }
                }

                if let stats = runStats {
                    HStack(spacing: 8) {
                        Text(Date(), style: .time)
                            .font(.caption2)
                        RunStatsView(durationMs: stats.durationMs, costUsd: stats.costUsd)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            Color.accentColor
                .opacity(pulse ? 0.06 : 0.02)
        )
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

private enum StreamingSegment {
    case text(String)
    case tools([ToolCall])
}

struct RunStatsView: View {
    let durationMs: Int
    let costUsd: Double

    var body: some View {
        HStack(spacing: 10) {
            StatLabel(icon: "timer", text: formattedDuration)
            StatLabel(icon: "dollarsign.circle", text: formattedCost)
        }
    }

    private var formattedDuration: String {
        let seconds = Double(durationMs) / 1000.0
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = Int(seconds) / 60
            let remainingSeconds = Int(seconds) % 60
            return "\(minutes)m \(remainingSeconds)s"
        }
    }

    private var formattedCost: String {
        if costUsd < 0.01 {
            return String(format: "$%.4f", costUsd)
        } else {
            return String(format: "$%.2f", costUsd)
        }
    }
}
