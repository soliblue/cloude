//
//  ChatView+MessageBubble.swift
//  Cloude
//

import SwiftUI
import UIKit

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showCopiedToast = false

    private var hasPositionedToolCalls: Bool {
        message.toolCalls.contains { $0.textPosition != nil && $0.parentToolId == nil }
    }

    private var isSlashCommand: Bool {
        message.isUser && message.text.hasPrefix("/")
    }

    private var slashCommandInfo: (name: String, icon: String)? {
        guard isSlashCommand else { return nil }
        let text = message.text.dropFirst()
        let name = String(text.split(separator: " ").first ?? Substring(text))
        let icon: String
        switch name {
        case "compact": icon = "arrow.triangle.2.circlepath"
        case "context": icon = "chart.pie"
        case "cost": icon = "dollarsign.circle"
        default: icon = "command"
        }
        return (name, icon)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !message.isUser && !message.toolCalls.isEmpty {
                ToolCallsSection(toolCalls: message.toolCalls)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    if message.wasInterrupted {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 15))
                            .foregroundColor(.orange)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if let imageBase64 = message.imageBase64,
                           let imageData = Data(base64Encoded: imageBase64),
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        if !message.text.isEmpty {
                            Group {
                                if isSlashCommand, let info = slashCommandInfo {
                                    SlashCommandBubble(command: message.text, icon: info.icon)
                                } else if message.isUser {
                                    Text(message.text)
                                } else if hasPositionedToolCalls {
                                    InterleavedMessageContent(text: message.text, toolCalls: message.toolCalls)
                                } else {
                                    StreamingMarkdownView(text: message.text)
                                }
                            }
                            .font(.body)
                        }
                    }
                    .opacity(message.isQueued ? 0.6 : 1.0)
                }

                if !message.isUser, let durationMs = message.durationMs, let costUsd = message.costUsd {
                    HStack(spacing: 8) {
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                        RunStatsView(durationMs: durationMs, costUsd: costUsd)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, message.toolCalls.isEmpty ? 12 : 4)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(message.isUser ? Color(.systemBackground) : Color(.systemGray6).opacity(0.3))
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.text
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { showCopiedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showCopiedToast = false }
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
            .overlay(alignment: .top) {
                if showCopiedToast {
                    CopiedToast()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
}

struct CopiedToast: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
            Text("Copied")
        }
        .font(.subheadline.weight(.medium))
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.darkGray))
        .cornerRadius(20)
        .shadow(radius: 4)
        .padding(.top, 8)
    }
}

struct InterleavedMessageContent: View {
    let text: String
    let toolCalls: [ToolCall]

    private var groupedSegments: [GroupedSegment] {
        let sortedTools = toolCalls
            .filter { $0.parentToolId == nil && $0.textPosition != nil }
            .sorted { ($0.textPosition ?? 0) < ($1.textPosition ?? 0) }

        var result: [GroupedSegment] = []
        var currentIndex = 0
        var pendingTools: [ToolCall] = []
        var hasAddedText = false

        for tool in sortedTools {
            let position = tool.textPosition ?? 0
            if position > currentIndex && position <= text.count {
                if !pendingTools.isEmpty && hasAddedText {
                    result.append(.tools(pendingTools))
                }
                pendingTools = []
                let startIdx = text.index(text.startIndex, offsetBy: currentIndex)
                let endIdx = text.index(text.startIndex, offsetBy: position)
                let segment = String(text[startIdx..<endIdx])
                if !segment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(.text(segment))
                    hasAddedText = true
                }
                currentIndex = position
            }
            pendingTools.append(tool)
        }

        if !pendingTools.isEmpty && hasAddedText {
            result.append(.tools(pendingTools))
        }

        if currentIndex < text.count {
            let startIdx = text.index(text.startIndex, offsetBy: currentIndex)
            let remaining = String(text[startIdx...])
            if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(.text(remaining))
            }
        }

        if result.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(.text(text))
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(groupedSegments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let content):
                    StreamingMarkdownView(text: content)
                case .tools(let tools):
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(tools.reversed().enumerated()), id: \.offset) { _, tool in
                                InlineToolPill(toolCall: tool)
                            }
                        }
                    }
                }
            }
        }
    }
}

private enum GroupedSegment {
    case text(String)
    case tools([ToolCall])
}

struct InlineToolPill: View {
    let toolCall: ToolCall

    var body: some View {
        ToolCallLabel(name: toolCall.name, input: toolCall.input, size: .small)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(toolCallColor(for: toolCall.name, input: toolCall.input).opacity(0.12))
            .cornerRadius(14)
    }
}

struct SlashCommandBubble: View {
    let command: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(command)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
        }
        .foregroundColor(.cyan)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.cyan.opacity(0.12))
        .cornerRadius(18)
    }
}
