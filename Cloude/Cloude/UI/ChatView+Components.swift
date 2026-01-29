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

    private var topLevelCalls: [ToolCall] {
        toolCalls.filter { $0.parentToolId == nil }
    }

    private func children(of toolId: String) -> [ToolCall] {
        toolCalls.filter { $0.parentToolId == toolId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(topLevelCalls.enumerated()), id: \.offset) { _, toolCall in
                ExpandableToolCall(
                    toolCall: toolCall,
                    children: children(of: toolCall.toolId)
                )
            }
        }
    }
}

struct ExpandableToolCall: View {
    let toolCall: ToolCall
    let children: [ToolCall]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: { if !children.isEmpty { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } } }) {
                HStack(spacing: 6) {
                    if !children.isEmpty {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 12)
                    }
                    Image(systemName: iconName(for: toolCall.name))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    Text(displayText)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if !children.isEmpty {
                        Text("(\(children.count))")
                            .font(.system(size: 11))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(.tertiaryLabel))
                                .frame(width: 1)
                                .padding(.leading, 16)
                            ToolCallRow(name: child.name, input: child.input)
                        }
                    }
                }
                .padding(.leading, 8)
                .transition(.opacity)
            }
        }
    }

    private var displayText: String {
        if let input = toolCall.input, !input.isEmpty {
            if toolCall.name == "Task" {
                return input  // Shows "Explore: Find files"
            }
            return "\(toolCall.name): \(input)"
        }
        return toolCall.name
    }

    private func iconName(for name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("read"): return "doc.text"
        case let n where n.contains("write"), let n where n.contains("edit"): return "pencil"
        case let n where n.contains("bash"), let n where n.contains("shell"): return "terminal"
        case let n where n.contains("glob"), let n where n.contains("search"): return "magnifyingglass"
        case let n where n.contains("task"), let n where n.contains("agent"): return "person.2"
        default: return "wrench"
        }
    }
}

