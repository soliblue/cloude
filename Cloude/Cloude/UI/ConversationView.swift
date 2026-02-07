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

            if let teamName = output?.teamName, !(output?.teammates.isEmpty ?? true) {
                TeamBannerView(
                    teamName: teamName,
                    teammates: output?.teammates ?? []
                )
            }

            ZStack(alignment: .trailing) {
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
                    onNewConversation: onNewConversation
                )

                if let mates = output?.teammates, !mates.isEmpty {
                    TeamOrbsOverlay(teammates: mates, onClearUnread: { mateId in
                        if let idx = output?.teammates.firstIndex(where: { $0.id == mateId }) {
                            output?.teammates[idx].unreadCount = 0
                        }
                    })
                }
            }
        }
        .onChange(of: output?.isRunning) { oldValue, newValue in
            if oldValue == true && newValue == false {
                handleCompletion()
            }
        }
    }

    private func handleCompletion() {
        guard let output = convOutput, !output.text.isEmpty, !output.isRunning else { return }

        if scenePhase != .active {
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
        if assistantCount > 0 && assistantCount % 5 == 0 {
            let recentMessages = updatedConv.messages.suffix(6).map { $0.text }
            let lastUserMsg = updatedConv.messages.last(where: { $0.isUser })?.text ?? ""
            connection.requestNameSuggestion(text: lastUserMsg, context: recentMessages, conversationId: conv.id)
        }

        store.replayQueuedMessages(conversation: conv, connection: connection)
    }

    private func refreshMissedResponse() async {
        guard let conv = effectiveConversation,
              let sessionId = conv.sessionId,
              let workingDir = conv.workingDirectory, !workingDir.isEmpty else { return }
        connection.syncHistory(sessionId: sessionId, workingDirectory: workingDir)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}
