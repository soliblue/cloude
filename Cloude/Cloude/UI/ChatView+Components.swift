//
//  ChatView+Components.swift
//  Cloude
//
//  Chat view UI components
//

import SwiftUI

struct StreamingOutput: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Claude is responding...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Text(text)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
    }
}

struct RunStatsView: View {
    let durationMs: Int
    let costUsd: Double

    var body: some View {
        HStack(spacing: 12) {
            Label(formattedDuration, systemImage: "clock")
            Label(formattedCost, systemImage: "dollarsign.circle")
        }
        .font(.caption)
        .foregroundColor(.secondary)
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

struct ToolCallsSection: View {
    let toolCalls: [ToolCall]
    @State private var expandedToolId: String?

    private var topLevelCalls: [ToolCall] {
        toolCalls.filter { $0.parentToolId == nil }
    }

    private func children(of toolId: String) -> [ToolCall] {
        toolCalls.filter { $0.parentToolId == toolId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(topLevelCalls.enumerated()), id: \.offset) { _, toolCall in
                        ToolPill(
                            toolCall: toolCall,
                            childCount: children(of: toolCall.toolId).count,
                            isExpanded: expandedToolId == toolCall.toolId
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if expandedToolId == toolCall.toolId {
                                    expandedToolId = nil
                                } else if !children(of: toolCall.toolId).isEmpty {
                                    expandedToolId = toolCall.toolId
                                }
                            }
                        }
                    }
                }
            }

            if let expandedId = expandedToolId {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(children(of: expandedId).enumerated()), id: \.offset) { _, child in
                        ToolCallRow(name: child.name, input: child.input)
                    }
                }
                .padding(.leading, 8)
                .transition(.opacity)
            }
        }
    }
}

struct ToolPill: View {
    let toolCall: ToolCall
    let childCount: Int
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .medium))
            Text(displayText)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
            if childCount > 0 {
                Text("(\(childCount))")
                    .font(.system(size: 10))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isExpanded ? Color(.secondarySystemBackground) : Color(.tertiarySystemBackground))
        .cornerRadius(14)
    }

    private var displayText: String {
        if let input = toolCall.input, !input.isEmpty {
            if toolCall.name == "Task" {
                let parts = input.split(separator: ":", maxSplits: 1)
                return parts.first.map(String.init) ?? input
            }
            return toolCall.name
        }
        return toolCall.name
    }

    private var iconName: String {
        switch toolCall.name.lowercased() {
        case let n where n.contains("read"): return "doc.text"
        case let n where n.contains("write"), let n where n.contains("edit"): return "pencil"
        case let n where n.contains("bash"), let n where n.contains("shell"): return "terminal"
        case let n where n.contains("glob"), let n where n.contains("search"): return "magnifyingglass"
        case let n where n.contains("task"), let n where n.contains("agent"): return "person.2"
        default: return "wrench"
        }
    }
}

