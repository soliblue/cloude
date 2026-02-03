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
        guard message.isUser else { return false }
        return message.text.hasPrefix("/") || message.text.contains("<command-name>")
    }

    private var slashCommandInfo: (name: String, icon: String, isBuiltIn: Bool)? {
        guard isSlashCommand else { return nil }

        let commandName: String
        if message.text.contains("<command-name>") {
            if let start = message.text.range(of: "<command-name>"),
               let end = message.text.range(of: "</command-name>") {
                let nameWithSlash = String(message.text[start.upperBound..<end.lowerBound])
                commandName = nameWithSlash.hasPrefix("/") ? String(nameWithSlash.dropFirst()) : nameWithSlash
            } else {
                return nil
            }
        } else {
            let text = message.text.dropFirst()
            commandName = String(text.split(separator: " ").first ?? Substring(text))
        }

        switch commandName {
        case "clear": return (commandName, "trash", true)
        case "compact": return (commandName, "arrow.triangle.2.circlepath", true)
        case "context": return (commandName, "chart.pie", true)
        case "cost": return (commandName, "dollarsign.circle", true)
        default: return (commandName, "command", false)
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
                        SlashCommandBubble(command: "/\(info.name)", icon: info.icon, isSkill: !info.isBuiltIn)
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
    var children: [ToolCall] = []
    @Environment(\.openURL) private var openURL
    @State private var showDetail = false
    @State private var isExpanded = false

    private var isMemoryCommand: Bool {
        toolCall.name == "Bash" && (toolCall.input?.hasPrefix("cloude memory ") ?? false)
    }

    private var isScript: Bool {
        guard toolCall.name == "Bash", let input = toolCall.input else { return false }
        return BashCommandParser.isScript(input)
    }

    private var chainedCommands: [String] {
        guard toolCall.name == "Bash", let input = toolCall.input else { return [] }
        if isScript { return [] }
        let commands = BashCommandParser.splitChainedCommands(input)
        return commands.count > 1 ? commands : []
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

    private var hasQuickAction: Bool {
        if !chainedCommands.isEmpty { return false }
        return isMemoryCommand || filePath != nil
    }

    private func performQuickAction() {
        if isMemoryCommand {
            if let url = URL(string: "cloude://memory") {
                openURL(url)
            }
        } else if let path = filePath,
                  let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "cloude://file\(encodedPath)") {
            openURL(url)
        }
    }

    var body: some View {
        Group {
            if children.isEmpty {
                pillContent
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    pillContent

                    if isExpanded {
                        ForEach(children, id: \.toolId) { child in
                            InlineToolPill(toolCall: child)
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                    if hasQuickAction {
                        performQuickAction()
                    } else {
                        showDetail = true
                    }
                }
        )
        .onLongPressGesture {
            showDetail = true
        }
        .sheet(isPresented: $showDetail) {
            ToolDetailSheet(toolCall: toolCall)
        }
    }

    private var pillContent: some View {
        HStack(spacing: 4) {
            if !chainedCommands.isEmpty {
                chainedPillContent
            } else {
                ToolCallLabel(name: toolCall.name, input: toolCall.input, size: .small)
                    .lineLimit(1)
            }

            if !children.isEmpty {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(toolCallColor(for: toolCall.name, input: toolCall.input).opacity(0.12))
        .cornerRadius(14)
    }

    private var chainedPillContent: some View {
        HStack(spacing: 6) {
            ForEach(Array(chainedCommands.prefix(3).enumerated()), id: \.offset) { index, cmd in
                if index > 0 {
                    Image(systemName: "link")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                let parsed = BashCommandParser.parse(cmd)
                Text(parsed.command.isEmpty ? "cmd" : parsed.command)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(toolCallColor(for: "Bash", input: cmd))
            }
            if chainedCommands.count > 3 {
                Text("+\(chainedCommands.count - 3)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
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

