import SwiftUI
import CloudeShared

struct ConversationView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var store: ConversationStore
    @Environment(\.scenePhase) var scenePhase

    let conversation: Conversation?
    var window: ChatWindow?
    var windowManager: WindowManager?
    var isCompact: Bool = false
    var showHeader: Bool = false
    var isKeyboardVisible: Bool = false
    var onSelectConversation: (() -> Void)?
    var onInteraction: (() -> Void)?
    var onSelectRecentConversation: ((Conversation) -> Void)?
    var onShowAllConversations: (() -> Void)?
    var onNewConversation: (() -> Void)?

    @State private var scrollProxy: ScrollViewProxy?

    private var effectiveConversation: Conversation? {
        if let conversation = conversation {
            return store.conversation(withId: conversation.id) ?? conversation
        }
        return store.currentConversation
    }

    private var messages: [ChatMessage] {
        effectiveConversation?.messages ?? []
    }

    private var queuedMessages: [ChatMessage] {
        effectiveConversation?.pendingMessages ?? []
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
                    conversation: effectiveConversation,
                    onSelectConversation: onSelectConversation
                )
                Divider()
            }
            ChatMessageList(
                messages: messages,
                queuedMessages: queuedMessages,
                currentOutput: output?.text ?? "",
                currentToolCalls: output?.toolCalls ?? [],
                currentRunStats: isCompact ? nil : output?.runStats,
                scrollProxy: $scrollProxy,
                agentState: isThisConversationRunning ? .running : .idle,
                conversationId: effectiveConversation?.id,
                isCompacting: output?.isCompacting ?? false,
                onRefresh: refreshMissedResponse,
                onInteraction: onInteraction,
                onDeleteQueued: { messageId in
                    if let conv = effectiveConversation {
                        store.removePendingMessage(messageId, from: conv)
                    }
                },
                conversation: effectiveConversation,
                conversationStore: store,
                connection: connection,
                window: window,
                windowManager: windowManager,
                onSelectConversation: onSelectRecentConversation,
                onShowAllConversations: onShowAllConversations,
                onNewConversation: onNewConversation
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

        if var conv = effectiveConversation {
            if let newSessionId = output.newSessionId {
                store.updateSessionId(conv, sessionId: newSessionId, workingDirectory: conv.workingDirectory)
                conv = store.conversation(withId: conv.id) ?? conv
            }

            let messageId = UUID()
            if output.lastSavedMessageId == messageId { return }

            let message = ChatMessage(
                isUser: false,
                text: output.text.trimmingCharacters(in: .whitespacesAndNewlines),
                toolCalls: output.toolCalls,
                durationMs: output.runStats?.durationMs,
                costUsd: output.runStats?.costUsd,
                serverUUID: output.messageUUID
            )

            let freshConv = store.conversation(withId: conv.id) ?? conv
            let isDuplicate: Bool
            if let uuid = output.messageUUID {
                isDuplicate = freshConv.messages.contains { $0.serverUUID == uuid }
            } else {
                isDuplicate = freshConv.messages.contains { !$0.isUser && $0.text == message.text && abs($0.timestamp.timeIntervalSinceNow) < 5 }
            }
            guard !isDuplicate else {
                output.reset()
                return
            }

            output.lastSavedMessageId = messageId
            store.addMessage(message, to: conv)
            output.reset()

            sendQueuedMessages(conv: conv)
        }
    }

    private func sendQueuedMessages(conv: Conversation) {
        let freshConv = store.conversation(withId: conv.id) ?? conv
        let pending = store.popPendingMessages(from: freshConv)
        guard !pending.isEmpty else { return }

        for var msg in pending {
            msg.isQueued = false
            store.addMessage(msg, to: freshConv)
        }

        let combinedText = pending.map { $0.text }.joined(separator: "\n\n")
        let updatedConv = store.conversation(withId: conv.id) ?? conv
        let workingDir = updatedConv.workingDirectory
        connection.sendChat(combinedText, workingDirectory: workingDir, sessionId: updatedConv.sessionId, isNewSession: false, conversationId: updatedConv.id, conversationName: updatedConv.name, conversationSymbol: updatedConv.symbol)
    }

    private func refreshMissedResponse() async {
        guard let conv = effectiveConversation,
              let sessionId = conv.sessionId,
              let workingDir = conv.workingDirectory, !workingDir.isEmpty else { return }
        connection.syncHistory(sessionId: sessionId, workingDirectory: workingDir)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}
