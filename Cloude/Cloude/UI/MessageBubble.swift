// MessageBubble.swift

import SwiftUI
import UIKit
import CloudeShared

struct MessageBubble: View {
    let message: ChatMessage
    var skills: [Skill] = []
    var liveOutput: ConversationOutput?
    var liveText: String?
    var liveToolCalls: [ToolCall]?
    var onRefresh: (() -> Void)?
    var isRefreshing: Bool = false
    var isCompact: Bool = false
    @State private var showCopiedToast = false
    @State private var showTextSelection = false
    @State private var selectedToolDetail: ToolDetailItem?
    @Environment(\.appTheme) private var appTheme

    private var isLive: Bool { liveOutput != nil }
    private var effectiveText: String {
        if let liveText, !liveText.isEmpty {
            return liveText
        }
        return message.text
    }
    private var effectiveToolCalls: [ToolCall] {
        if let liveToolCalls, !liveToolCalls.isEmpty {
            return liveToolCalls
        }
        return message.toolCalls
    }

    private var hasInteractiveWidgets: Bool {
        effectiveToolCalls.contains { WidgetRegistry.isWidget($0.name) }
    }

    private var hasToolCalls: Bool {
        effectiveToolCalls.contains { $0.parentToolId == nil }
    }

    private var isSlashCommand: Bool {
        guard message.isUser else { return false }
        return message.text.hasPrefix("/") || message.text.contains("<command-name>")
    }

    private var slashCommandInfo: (name: String, args: String?, icon: String, isBuiltIn: Bool)? {
        guard isSlashCommand else { return nil }
        return parseSlashCommand(text: message.text, skills: skills)
    }

    private var backgroundColor: Color {
        if message.wasInterrupted {
            return Color.orange.opacity(DS.Opacity.s)
        } else if message.isUser {
            return Color(hex: appTheme.palette.background)
        } else {
            return Color(hex: appTheme.palette.secondary).opacity(DS.Opacity.m)
        }
    }

    var body: some View {
        #if DEBUG
        let _ = DebugMetrics.log(
            "Bubble",
            "render | \(message.isUser ? "user" : "asst") id=\(message.id.uuidString.prefix(6)) " +
            "isLive=\(isLive) msg=\(message.text.count)ch live=\((liveText ?? "").count)ch " +
            "effective=\(effectiveText.count)ch"
        )
        #endif
        messageContent
            .opacity(message.isQueued ? DS.Opacity.l : 1.0)
        .onChange(of: isLive) { old, new in
            #if DEBUG
            DebugMetrics.log(
                "Bubble",
                "isLive \(old)->\(new) id=\(message.id.uuidString.prefix(6)) " +
                "msg=\(message.text.count)ch live=\((liveText ?? "").count)ch " +
                "effective=\(effectiveText.count)ch"
            )
            #endif
        }
        .padding(DS.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .modifier(BubbleInteractionModifier(
            isLive: isLive,
            message: message,
            effectiveText: effectiveText,
            hasInteractiveWidgets: hasInteractiveWidgets,
            showCopiedToast: $showCopiedToast,
            showTextSelection: $showTextSelection,
            onRefresh: onRefresh,
            isRefreshing: isRefreshing
        ))
    }

    private var statusBarItems: [(icon: String, text: String)] {
        var items: [(String, String)] = []
        if let model = message.model {
            let identity = ModelIdentity(model)
            items.append((identity.icon, identity.displayName))
        }
        if let cost = message.costUsd {
            items.append(("dollarsign.circle", cost.asCost))
        }
        if let ms = message.durationMs {
            let s = Double(ms) / 1000.0
            items.append(("timer", s < 60 ? String(format: "%.1fs", s) : "\(Int(s)/60)m \(Int(s)%60)s"))
        }
        return items
    }

    private var messageContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            MessageImageThumbnails(message: message)

            Group {
                if isSlashCommand, let info = slashCommandInfo {
                    SlashCommandBubble(command: "/\(info.name)", args: info.args, icon: info.icon, isSkill: !info.isBuiltIn)
                } else if message.isUser, message.text.hasPrefix("[whiteboard snapshot]") {
                    WhiteboardSnapshotPill(text: message.text)
                } else if message.isUser {
                    if !message.text.isEmpty {
                        Text(message.text)
                        .font(.system(size: DS.Text.m))
                    }
                } else if isLive && (liveOutput?.isCompacting ?? false) {
                    CompactingIndicator()
                } else if hasToolCalls {
                    StreamingMarkdownView(text: effectiveText, toolCalls: effectiveToolCalls) { tool, children in
                        selectedToolDetail = ToolDetailItem(toolCall: tool, children: children)
                    }
                } else if !effectiveText.isEmpty {
                    StreamingMarkdownView(text: effectiveText)
                } else if isLive {
                    SisyphusLoadingView()
                }
            }
            .font(.system(size: DS.Text.m))

            if !isLive && !message.isUser && !statusBarItems.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(Array(statusBarItems.enumerated()), id: \.offset) { i, item in
                        if i > 0 {
                            Text("·")
                                .foregroundColor(.secondary.opacity(DS.Opacity.m))
                        }
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: item.icon)
                            Text(item.text)
                        }
                    }
                }
                .font(.system(size: DS.Text.s))
                .foregroundColor(.secondary.opacity(DS.Opacity.l))
            }
        }
        .sheet(item: $selectedToolDetail) { item in
            ToolDetailSheet(toolCall: item.toolCall, children: item.children)
        }
    }


}
