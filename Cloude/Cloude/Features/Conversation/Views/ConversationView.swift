import SwiftUI
import CloudeShared

struct ConversationView: View {
    let connection: ConnectionManager
    let store: ConversationStore
    var environmentStore: EnvironmentStore?
    @Environment(\.scenePhase) var scenePhase

    let conversation: Conversation?
    var window: Window?
    var windowManager: WindowManager?
    var onSelectConversation: (() -> Void)?
    var onInteraction: (() -> Void)?
    var onSelectRecentConversation: ((Conversation) -> Void)?
    var onSeeAllConversations: (() -> Void)?

    private var effectiveConversation: Conversation? {
        if let conversation = conversation {
            return store.conversation(withId: conversation.id) ?? conversation
        }
        return nil
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
        #if DEBUG
        let _ = DebugMetrics.log("ConvView", "render | msgs=\(messages.count)")
        #endif
        let output = convOutput

        VStack(spacing: 0) {
            ChatMessageList(
                messages: messages,
                queuedMessages: queuedMessages,
                conversationId: effectiveConversation?.id,
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
                onSeeAllConversations: onSeeAllConversations,
                environmentStore: environmentStore,
                conversationOutput: output
            )
        }
        .onChange(of: output?.isRunning) { oldValue, newValue in
            if oldValue == true && newValue == false {
                handleCompletion()
            }
        }
    }

    private func handleCompletion() {
        guard let output = convOutput, !output.isRunning else { return }

        if scenePhase != .active && !output.text.isEmpty {
            NotificationManager.showCompletionNotification(preview: output.text)
        }

        guard var conv = effectiveConversation else { return }

        if let newSessionId = output.newSessionId {
            store.updateSessionId(conv, sessionId: newSessionId, workingDirectory: conv.workingDirectory)
            conv = store.conversation(withId: conv.id) ?? conv
        }

        store.finalizeStreamingMessage(output: output, conversation: conv)

        let updatedConv = store.conversation(withId: conv.id) ?? conv
        let assistantCount = updatedConv.messages.filter { !$0.isUser }.count
        let shouldRename = assistantCount == 2 || (assistantCount > 0 && assistantCount % 5 == 0)
        if shouldRename {
            let contextMessages = updatedConv.messages.suffix(10).map {
                ($0.isUser ? "User: " : "Assistant: ") + String($0.text.prefix(300))
            }
            let lastUserMsg = updatedConv.messages.last(where: { $0.isUser })?.text ?? ""
            connection.requestNameSuggestion(text: lastUserMsg, context: contextMessages, conversationId: conv.id)
        }

        store.replayQueuedMessages(conversation: conv, connection: connection)
    }

    private func refreshMissedResponse() async {
        guard let conv = effectiveConversation,
              let sessionId = conv.sessionId,
              let workingDir = conv.workingDirectory, !workingDir.isEmpty else { return }
        connection.syncHistory(sessionId: sessionId, workingDirectory: workingDir)
        try? await Task.sleep(for: .seconds(1))
    }
}
