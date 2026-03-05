import SwiftUI
import UIKit
import CloudeShared

struct MessageBubble: View {
    let message: ChatMessage
    var skills: [Skill] = []
    var onRefresh: (() -> Void)?
    var onToggleCollapse: (() -> Void)?
    @State private var showCopiedToast = false
    @State private var showTeamDashboard = false
    @State private var showTextSelection = false
    @State private var showLongPressMenu = false
    @State private var menuPressY: CGFloat = 0
    @AppStorage("ttsMode") private var ttsMode: TTSMode = .off
    @AppStorage("kokoroVoice") private var kokoroVoice: KokoroVoice = .af_heart
    @ObservedObject private var ttsService = TTSService.shared

    private var hasInteractiveWidgets: Bool {
        message.toolCalls.contains { WidgetRegistry.isWidget($0.name) }
    }

    private var hasToolCalls: Bool {
        !message.toolCalls.filter { $0.parentToolId == nil }.isEmpty
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
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
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
                        .clipShape(RoundedRectangle(cornerRadius: 6))
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
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .opacity(message.isQueued ? 0.6 : 1.0)

            if message.isUser {
                HStack(spacing: 8) {
                    StatLabel(icon: "clock", text: DateFormatters.messageTimestamp(message.timestamp))
                    StatLabel(icon: "textformat.size", text: "\(message.text.count)")
                }
                .foregroundColor(.secondary)
            } else {
                if let team = message.teamSummary {
                    TeamSummaryBadge(summary: team, onTap: { showTeamDashboard = true })
                }
                HStack(spacing: 8) {
                    if let durationMs = message.durationMs, let costUsd = message.costUsd {
                        StatLabel(icon: "clock", text: DateFormatters.messageTimestamp(message.timestamp))
                        RunStatsView(durationMs: durationMs, costUsd: costUsd, model: message.model)
                    }
                    Spacer()
                    if ttsMode != .off && !message.text.isEmpty {
                        if ttsService.isSynthesizing && ttsService.playingMessageId == message.id.uuidString {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 14, height: 14)
                        } else {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                ttsService.speak(message.text, messageId: message.id.uuidString, mode: ttsMode, voice: kokoroVoice.rawValue)
                            } label: {
                                Image(systemName: ttsService.playingMessageId == message.id.uuidString ? "stop.fill" : "speaker.wave.2")
                                    .font(.system(size: 9))
                                    .foregroundColor(ttsService.playingMessageId == message.id.uuidString ? .purple : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        ClipboardHelper.copy(message.text)
                        withAnimation { showCopiedToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showCopiedToast = false }
                        }
                    } label: {
                        Image(systemName: "square.on.square")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    if let onRefresh {
                        Button(action: onRefresh) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
            .sheet(isPresented: $showTextSelection) {
                TextSelectionSheet(text: message.text, isMarkdown: !message.isUser)
            }
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
            .overlay(alignment: .top) {
                if showCopiedToast {
                    CopiedToast()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay {
                if showLongPressMenu {
                    GeometryReader { geo in
                        let menuY = min(max(menuPressY - 60, 0), geo.size.height - 60)
                        let origin = geo.frame(in: .global).origin
                        Color.black.opacity(0.01)
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                            .position(x: UIScreen.main.bounds.width / 2 - origin.x, y: UIScreen.main.bounds.height / 2 - origin.y)
                            .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { showLongPressMenu = false } }

                        BubbleActionMenu(
                            message: message,
                            ttsMode: ttsMode,
                            ttsService: ttsService,
                            kokoroVoice: kokoroVoice,
                            onCopy: {
                                ClipboardHelper.copy(message.text)
                                withAnimation { showCopiedToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation { showCopiedToast = false }
                                }
                            },
                            onSelectText: { showTextSelection = true },
                            onToggleCollapse: onToggleCollapse,
                            onDismiss: { withAnimation(.easeOut(duration: 0.15)) { showLongPressMenu = false } }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        .frame(maxWidth: .infinity)
                        .offset(y: menuY)
                    }
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        if hasInteractiveWidgets { return }
                        if case .second(true, let drag) = value {
                            menuPressY = drag?.location.y ?? 0
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { showLongPressMenu = true }
                        }
                    }
            )
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
        .cornerRadius(15)
        .shadow(radius: 4)
        .padding(.top, 8)
    }
}

struct BubbleActionMenu: View {
    let message: ChatMessage
    let ttsMode: TTSMode
    @ObservedObject var ttsService: TTSService
    let kokoroVoice: KokoroVoice
    let onCopy: () -> Void
    let onSelectText: () -> Void
    let onToggleCollapse: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            menuButton(icon: "doc.on.doc", label: "Copy") {
                onCopy()
                onDismiss()
            }
            if !message.text.isEmpty {
                divider
                menuButton(icon: "text.cursor", label: "Select") {
                    onSelectText()
                    onDismiss()
                }
            }
            if !message.isUser && !message.text.isEmpty {
                divider
                menuButton(icon: message.isCollapsed ? "chevron.down" : "chevron.up", label: message.isCollapsed ? "Expand" : "Collapse") {
                    onToggleCollapse?()
                    onDismiss()
                }
            }
            if ttsMode != .off && !message.text.isEmpty && !message.isUser {
                divider
                let isPlaying = ttsService.playingMessageId == message.id.uuidString
                menuButton(icon: isPlaying ? "stop.fill" : "speaker.wave.2", label: isPlaying ? "Stop" : "Play") {
                    ttsService.speak(message.text, messageId: message.id.uuidString, mode: ttsMode, voice: kokoroVoice.rawValue)
                    onDismiss()
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private func menuButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.primary)
            .frame(width: 64, height: 52)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 0.5, height: 32)
    }
}

struct ConditionalClip: ViewModifier {
    let isClipped: Bool
    func body(content: Content) -> some View {
        if isClipped {
            content.clipped()
        } else {
            content
        }
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

struct TextSelectionSheet: View {
    let text: String
    var isMarkdown: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var showCopied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                PlainSelectableText(text: text)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        ClipboardHelper.copy(text)
                        withAnimation { showCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showCopied = false }
                        }
                    } label: {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(showCopied ? .green : .secondary)
                    }
                }
            }
        }
    }
}

struct PlainSelectableText: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = .label
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.text = text
        textView.invalidateIntrinsicContentSize()
    }
}



