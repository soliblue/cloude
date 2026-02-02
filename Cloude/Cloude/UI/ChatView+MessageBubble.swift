//
//  ChatView+MessageBubble.swift
//  Cloude
//

import SwiftUI
import UIKit

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showCopiedToast = false

    private var hasToolCalls: Bool {
        !message.toolCalls.filter { $0.parentToolId == nil }.isEmpty
    }

    private var isSlashCommand: Bool {
        message.isUser && message.text.hasPrefix("/")
    }

    private var slashCommandInfo: (name: String, icon: String, isBuiltIn: Bool)? {
        guard isSlashCommand else { return nil }
        let text = message.text.dropFirst()
        let name = String(text.split(separator: " ").first ?? Substring(text))
        switch name {
        case "compact": return (name, "arrow.triangle.2.circlepath", true)
        case "context": return (name, "chart.pie", true)
        case "cost": return (name, "dollarsign.circle", true)
        default: return (name, "command", false)
        }
    }

    private var backgroundColor: Color {
        if message.wasInterrupted {
            return Color.orange.opacity(0.15)
        } else if message.isUser {
            return Color.oceanBackground
        } else {
            return Color.oceanGray6.opacity(0.3)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

                Group {
                    if isSlashCommand, let info = slashCommandInfo {
                        SlashCommandBubble(command: message.text, icon: info.icon, isSkill: !info.isBuiltIn)
                    } else if message.isUser {
                        if !message.text.isEmpty {
                            Text(message.text)
                        }
                    } else if hasToolCalls {
                        InterleavedMessageContent(text: message.text, toolCalls: message.toolCalls)
                    } else if !message.text.isEmpty {
                        StreamingMarkdownView(text: message.text)
                    }
                }
                .font(.body)
            }
            .opacity(message.isQueued ? 0.6 : 1.0)

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
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
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
        let topLevelTools = toolCalls
            .filter { $0.parentToolId == nil }
            .sorted { ($0.textPosition ?? 0) < ($1.textPosition ?? 0) }

        var result: [GroupedSegment] = []
        var currentIndex = 0
        var pendingTools: [ToolCall] = []

        for tool in topLevelTools {
            let position = tool.textPosition ?? 0
            if position > currentIndex && position <= text.count {
                let startIdx = text.index(text.startIndex, offsetBy: currentIndex)
                let endIdx = text.index(text.startIndex, offsetBy: position)
                let segment = String(text[startIdx..<endIdx])
                if !segment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if !pendingTools.isEmpty {
                        result.append(.tools(pendingTools))
                        pendingTools = []
                    }
                    result.append(.text(segment))
                    currentIndex = position
                }
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
                        .padding(.horizontal, 16)
                    }
                    .padding(.horizontal, -16)
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
    @Environment(\.openURL) private var openURL

    private var filePath: String? {
        guard ["Read", "Write", "Edit"].contains(toolCall.name),
              let input = toolCall.input else { return nil }
        return input
    }

    private var fileURL: URL? {
        guard let path = filePath,
              let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "cloude://file\(encodedPath)")
    }

    var body: some View {
        pillContent
            .highPriorityGesture(
                TapGesture()
                    .onEnded {
                        print("[InlineToolPill] Tapped, filePath: \(filePath ?? "nil"), fileURL: \(fileURL?.absoluteString ?? "nil")")
                        if let url = fileURL {
                            openURL(url)
                        }
                    }
            )
    }

    private var pillContent: some View {
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
    var isSkill: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(command)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(isSkill ? skillGradient : builtInGradient)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSkill ? Color.purple.opacity(0.12) : Color.cyan.opacity(0.12))
                .overlay(
                    isSkill ?
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.pink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    : nil
                )
        )
    }

    private var skillGradient: LinearGradient {
        LinearGradient(
            colors: [.purple, .pink.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var builtInGradient: LinearGradient {
        LinearGradient(colors: [.cyan], startPoint: .leading, endPoint: .trailing)
    }
}
