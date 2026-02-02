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

    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' HH:mm"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d, HH:mm"
        } else {
            formatter.dateFormat = "MMM d yyyy, HH:mm"
        }
        return formatter.string(from: date)
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

            if message.isUser {
                HStack(spacing: 10) {
                    StatLabel(icon: "clock", text: formatTimestamp(message.timestamp))
                    StatLabel(icon: "textformat.size", text: "\(message.text.count)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } else if let durationMs = message.durationMs, let costUsd = message.costUsd {
                HStack(spacing: 10) {
                    StatLabel(icon: "clock", text: formatTimestamp(message.timestamp))
                    RunStatsView(durationMs: durationMs, costUsd: costUsd)
                }
                .font(.caption)
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

    var body: some View {
        StreamingMarkdownView(text: text, toolCalls: toolCalls)
    }
}

struct InlineToolPill: View {
    let toolCall: ToolCall
    @Environment(\.openURL) private var openURL

    private var isMemoryCommand: Bool {
        toolCall.name == "Bash" && (toolCall.input?.hasPrefix("cloude memory ") ?? false)
    }

    private var filePath: String? {
        guard let input = toolCall.input else { return nil }

        if ["Read", "Write", "Edit"].contains(toolCall.name) {
            return input
        }

        if toolCall.name == "Bash" && !isMemoryCommand {
            return extractFilePathFromBash(input)
        }

        return nil
    }

    private func extractFilePathFromBash(_ command: String) -> String? {
        let parsed = BashCommandParser.parse(command)

        if parsed.command == "git", let sub = parsed.subcommand {
            let fileSubcommands = ["add", "diff", "checkout", "restore", "show"]
            if fileSubcommands.contains(sub), parsed.allArgs.count == 1 {
                let arg = parsed.allArgs[0]
                if isValidPath(arg) { return arg }
            }
        }

        let singlePathCommands = ["ls", "cd", "mkdir", "touch", "open", "cat", "head", "tail"]
        if singlePathCommands.contains(parsed.command) {
            if let arg = parsed.firstArg, isValidPath(arg) { return arg }
        }

        let destCommands = ["cp", "mv"]
        if destCommands.contains(parsed.command), parsed.allArgs.count == 2 {
            let dest = parsed.allArgs[1]
            if isValidPath(dest) { return dest }
        }

        return nil
    }

    private func isValidPath(_ path: String) -> Bool {
        path.hasPrefix("/") && !path.contains("*") && !path.contains("?")
    }

    private var actionURL: URL? {
        if isMemoryCommand {
            return URL(string: "cloude://memory")
        }
        if let path = filePath,
           let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            return URL(string: "cloude://file\(encodedPath)")
        }
        return nil
    }

    var body: some View {
        pillContent
            .highPriorityGesture(
                TapGesture()
                    .onEnded {
                        if let url = actionURL {
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

