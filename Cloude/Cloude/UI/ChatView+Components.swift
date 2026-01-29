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
    @Binding var isExpanded: Bool

    private var topLevelCalls: [ToolCall] {
        toolCalls.filter { $0.parentToolId == nil }
    }

    private func children(of toolId: String) -> [ToolCall] {
        toolCalls.filter { $0.parentToolId == toolId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Text("\(toolCalls.count) tool call\(toolCalls.count == 1 ? "" : "s")")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

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
                    ForEach(Array(topLevelCalls.enumerated()), id: \.offset) { _, toolCall in
                        ToolCallRow(name: toolCall.name, input: toolCall.input)
                        let childCalls = children(of: toolCall.toolId)
                        if !childCalls.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(childCalls.enumerated()), id: \.offset) { _, child in
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .fill(Color(.tertiaryLabel))
                                            .frame(width: 1)
                                            .padding(.leading, 8)
                                        ToolCallRow(name: child.name, input: child.input)
                                    }
                                }
                            }
                            .padding(.leading, 12)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

