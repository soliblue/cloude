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
    var onSelectToolDetail: ((ToolDetailItem) -> Void)?
    @State private var showCopiedToast = false
    @State private var showTextSelection = false
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
        switch message.kind {
        case .assistant(let wasInterrupted) where wasInterrupted:
            return AppColor.orange.opacity(DS.Opacity.s)
        case .user:
            return Color(hex: appTheme.palette.tertiary)
        default:
            return .clear
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
            .opacity(message.kind == .user(isQueued: true) ? DS.Opacity.l : 1.0)
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
            showCopiedToast: $showCopiedToast,
            showTextSelection: $showTextSelection,
            onRefresh: onRefresh,
            isRefreshing: isRefreshing
        ))
    }

    private var messageContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            MessageImageThumbnails(message: message)

            Group {
                if isSlashCommand, let info = slashCommandInfo {
                    SlashCommandBubble(command: "/\(info.name)", args: info.args, icon: info.icon, isSkill: !info.isBuiltIn)
                } else if message.isUser {
                    if !message.text.isEmpty {
                        Text(message.text)
                        .font(.system(size: DS.Text.m))
                    }
                } else if isLive && liveOutput?.phase == .compacting {
                    CompactingIndicator()
                } else if hasToolCalls {
                    StreamingMarkdownView(text: effectiveText, toolCalls: effectiveToolCalls) { tool, children in
                        onSelectToolDetail?(ToolDetailItem(toolCall: tool, children: children))
                    }
                } else if !effectiveText.isEmpty {
                    StreamingMarkdownView(text: effectiveText)
                } else if isLive {
                    MessageBubbleLoadingView()
                }
            }
            .font(.system(size: DS.Text.m))

        }
    }


}
