import SwiftUI
import UIKit
import CloudeShared

struct MessageBubble: View {
    let message: ChatMessage
    var onRefresh: (() -> Void)?
    @State private var showCopiedToast = false
    @State private var showTeamDashboard = false

    private var hasToolCalls: Bool {
        !message.toolCalls.filter { $0.parentToolId == nil }.isEmpty
    }

    private var isSlashCommand: Bool {
        guard message.isUser else { return false }
        return message.text.hasPrefix("/") || message.text.contains("<command-name>")
    }

    private var slashCommandInfo: (name: String, args: String?, icon: String, isBuiltIn: Bool)? {
        guard isSlashCommand else { return nil }

        let commandName: String
        var commandArgs: String?
        if message.text.contains("<command-name>") {
            if let start = message.text.range(of: "<command-name>"),
               let end = message.text.range(of: "</command-name>") {
                let nameWithSlash = String(message.text[start.upperBound..<end.lowerBound])
                commandName = nameWithSlash.hasPrefix("/") ? String(nameWithSlash.dropFirst()) : nameWithSlash
            } else {
                return nil
            }
            if let argsStart = message.text.range(of: "<command-args>"),
               let argsEnd = message.text.range(of: "</command-args>") {
                let args = String(message.text[argsStart.upperBound..<argsEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !args.isEmpty { commandArgs = args }
            }
        } else {
            let text = message.text.dropFirst()
            let parts = text.split(separator: " ", maxSplits: 1)
            commandName = String(parts.first ?? Substring(text))
            if parts.count > 1 {
                let args = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !args.isEmpty { commandArgs = args }
            }
        }

        switch commandName {
        case "clear": return (commandName, commandArgs, "trash", true)
        case "compact": return (commandName, commandArgs, "arrow.triangle.2.circlepath", true)
        case "context": return (commandName, commandArgs, "chart.pie", true)
        case "cost": return (commandName, commandArgs, "dollarsign.circle", true)
        default: return (commandName, commandArgs, "command", false)
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        DateFormatters.messageTimestamp(date)
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
                if let thumbnails = message.imageThumbnails, thumbnails.count > 1 {
                    HStack(spacing: 4) {
                        ForEach(thumbnails.indices, id: \.self) { index in
                            if let imageData = Data(base64Encoded: thumbnails[index]),
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                } else if let imageBase64 = message.imageBase64,
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
                        SlashCommandBubble(command: "/\(info.name)", args: info.args, icon: info.icon, isSkill: !info.isBuiltIn)
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
            } else {
                HStack(spacing: 10) {
                    if let durationMs = message.durationMs, let costUsd = message.costUsd {
                        StatLabel(icon: "clock", text: formatTimestamp(message.timestamp))
                        RunStatsView(durationMs: durationMs, costUsd: costUsd)
                    }
                    if let onRefresh {
                        Button(action: onRefresh) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    if let team = message.teamSummary {
                        if message.durationMs != nil { Spacer() }
                        TeamSummaryBadge(summary: team, onTap: { showTeamDashboard = true })
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
            .sheet(isPresented: $showTeamDashboard) {
                if let team = message.teamSummary {
                    TeamDashboardSheet(
                        teamName: team.teamName,
                        teammates: team.members.map {
                            TeammateInfo(id: $0.name, name: $0.name, agentType: $0.agentType, model: $0.model, color: $0.color, status: .shutdown)
                        }
                    )
                }
            }
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

struct TeamSummaryBadge: View {
    let summary: TeamSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                HStack(spacing: -4) {
                    ForEach(summary.members) { member in
                        Circle()
                            .fill(teammateColor(member.color).opacity(0.6))
                            .frame(width: 14, height: 14)
                            .overlay {
                                Text(String(member.name.prefix(1)).uppercased())
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                    }
                }
                Text(summary.teamName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct SlashCommandBubble: View {
    let command: String
    var args: String? = nil
    let icon: String
    var isSkill: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(command)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            if let args = args {
                Text(args)
                    .font(.system(size: 12, design: .monospaced))
                    .opacity(0.7)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(isSkill ? skillGradient : builtInGradient)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SkillPillBackground(isSkill: isSkill))
    }
}
