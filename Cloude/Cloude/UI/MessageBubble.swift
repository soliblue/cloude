// MessageBubble.swift

import SwiftUI
import UIKit
import CloudeShared

struct MessageBubble: View {
    let message: ChatMessage
    var skills: [Skill] = []
    var liveOutput: ConversationOutput?
    var onRefresh: (() -> Void)?
    var onToggleCollapse: (() -> Void)?
    var isRefreshing: Bool = false
    var isCompact: Bool = false
    @State private var showCopiedToast = false
    @State private var showTextSelection = false
    @Environment(\.appTheme) private var appTheme

    private var isLive: Bool { liveOutput != nil }
    private var effectiveText: String { liveOutput?.text ?? message.text }
    private var effectiveToolCalls: [ToolCall] { liveOutput?.toolCalls ?? message.toolCalls }

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
            return Color.orange.opacity(0.15)
        } else if message.isUser {
            return Color(hex: appTheme.palette.background)
        } else {
            return Color(hex: appTheme.palette.secondary).opacity(0.3)
        }
    }

    var body: some View {
        #if DEBUG
        let _ = DebugMetrics.log("Bubble", "render | \(message.isUser ? "user" : "asst") id=\(message.id.uuidString.prefix(6))")
        #endif
        messageContent
            .opacity(message.isQueued ? 0.6 : 1.0)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .modifier(BubbleInteractionModifier(
            isLive: isLive,
            message: message,
            effectiveText: effectiveText,
            hasInteractiveWidgets: hasInteractiveWidgets,
            showCopiedToast: $showCopiedToast,
            showTextSelection: $showTextSelection,
            onToggleCollapse: onToggleCollapse,
            onRefresh: onRefresh,
            isRefreshing: isRefreshing
        ))
    }

    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    StreamingMarkdownView(text: effectiveText, toolCalls: effectiveToolCalls, isComplete: !isLive)
                } else if !effectiveText.isEmpty {
                    StreamingMarkdownView(text: effectiveText, isComplete: !isLive)
                } else if isLive {
                    SisyphusLoadingView()
                }
            }
            .font(.system(size: DS.Text.m))
            .frame(maxHeight: message.isCollapsed ? 120 : nil, alignment: .top)
            .modifier(ConditionalClip(isClipped: message.isCollapsed))
            .overlay(alignment: .bottom) {
                if message.isCollapsed {
                    LinearGradient(colors: [backgroundColor.opacity(0), backgroundColor], startPoint: .top, endPoint: .bottom)
                        .frame(height: 40)
                }
            }

            if message.isCollapsed {
                Button {
                    onToggleCollapse?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.down")
                        Text("Show more")
                            .font(.system(size: DS.Text.s))
                    }
                    .font(.system(size: DS.Text.s, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }
        }
    }


}
