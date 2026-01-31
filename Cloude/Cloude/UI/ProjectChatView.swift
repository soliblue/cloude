import SwiftUI
import CloudeShared

struct ProjectChatView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var store: ProjectStore
    @Environment(\.scenePhase) var scenePhase

    let project: Project?
    let conversation: Conversation?
    var isCompact: Bool = false
    var showHeader: Bool = false
    var isKeyboardVisible: Bool = false
    var onSelectConversation: (() -> Void)?
    var onInteraction: (() -> Void)?

    @State private var scrollProxy: ScrollViewProxy?

    private var effectiveProject: Project? {
        project ?? store.currentProject
    }

    private var effectiveConversation: Conversation? {
        conversation ?? store.currentConversation
    }

    private var messages: [ChatMessage] {
        let sent = effectiveConversation?.messages ?? []
        let pending = effectiveConversation?.pendingMessages ?? []
        return sent + pending
    }

    private var convOutput: ConversationOutput? {
        guard let convId = effectiveConversation?.id else { return nil }
        return connection.output(for: convId)
    }

    private var isThisConversationRunning: Bool {
        convOutput?.isRunning ?? false
    }

    var body: some View {
        let output = convOutput

        VStack(spacing: 0) {
            if showHeader {
                WindowHeaderView(
                    project: effectiveProject,
                    conversation: effectiveConversation,
                    onSelectConversation: onSelectConversation
                )
                Divider()
            }
            ProjectChatMessageList(
                messages: messages,
                currentOutput: output?.text ?? "",
                currentToolCalls: output?.toolCalls ?? [],
                currentRunStats: isCompact ? nil : output?.runStats,
                scrollProxy: $scrollProxy,
                agentState: isThisConversationRunning ? .running : .idle,
                conversationId: effectiveConversation?.id,
                isCompacting: output?.isCompacting ?? false,
                onRefresh: refreshMissedResponse,
                onInteraction: onInteraction
            )
        }
        .onChange(of: output?.isRunning) { oldValue, newValue in
            if oldValue == true && newValue == false {
                handleCompletion()
            }
        }
    }

    private func handleCompletion() {
        guard effectiveConversation?.id != nil else { return }
        guard let output = convOutput else { return }
        guard !output.text.isEmpty else { return }
        guard output.isRunning == false else { return }

        if scenePhase != .active {
            NotificationManager.showCompletionNotification(preview: output.text)
        }

        if let proj = effectiveProject, var conv = effectiveConversation {
            if let newSessionId = output.newSessionId {
                store.updateSessionId(conv, in: proj, sessionId: newSessionId)
                conv = store.projects.first { $0.id == proj.id }?.conversations.first { $0.id == conv.id } ?? conv
            }

            let messageId = UUID()
            if output.lastSavedMessageId == messageId { return }

            let message = ChatMessage(
                isUser: false,
                text: output.text.trimmingCharacters(in: .whitespacesAndNewlines),
                toolCalls: output.toolCalls,
                durationMs: output.runStats?.durationMs,
                costUsd: output.runStats?.costUsd
            )

            let freshConv = store.projects.first { $0.id == proj.id }?.conversations.first { $0.id == conv.id } ?? conv
            let isDuplicate = freshConv.messages.contains { !$0.isUser && $0.text == message.text && abs($0.timestamp.timeIntervalSinceNow) < 5 }
            guard !isDuplicate else {
                output.reset()
                return
            }

            output.lastSavedMessageId = messageId
            store.addMessage(message, to: conv, in: proj)
            output.reset()

            sendQueuedMessages(proj: proj, conv: conv)
        }
    }

    private func sendQueuedMessages(proj: Project, conv: Conversation) {
        let freshConv = store.projects.first { $0.id == proj.id }?.conversations.first { $0.id == conv.id } ?? conv
        let pending = store.popPendingMessages(from: freshConv, in: proj)
        guard !pending.isEmpty else { return }

        for var msg in pending {
            msg.isQueued = false
            store.addMessage(msg, to: freshConv, in: proj)
        }

        let combinedText = pending.map { $0.text }.joined(separator: "\n\n")
        let updatedConv = store.projects.first { $0.id == proj.id }?.conversations.first { $0.id == conv.id } ?? conv
        let workingDir = proj.rootDirectory.isEmpty ? nil : proj.rootDirectory
        connection.sendChat(combinedText, workingDirectory: workingDir, sessionId: updatedConv.sessionId, isNewSession: false, conversationId: updatedConv.id)
    }

    private func refreshMissedResponse() async {
        guard let sessionId = effectiveConversation?.sessionId else { return }
        connection.requestMissedResponse(sessionId: sessionId)
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}
