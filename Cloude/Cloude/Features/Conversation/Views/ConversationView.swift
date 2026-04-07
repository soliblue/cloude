import SwiftUI
import Combine
import CloudeShared

struct ConversationView: View {
    let connection: ConnectionManager
    let store: ConversationStore
    var environmentStore: EnvironmentStore?

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
        let _ = NSLog("[STABILITY] ConversationView.body | msgs=\(messages.count) hasOutput=\(convOutput != nil) convId=\(effectiveConversation?.id.uuidString.prefix(6) ?? "nil")")
        content(output: convOutput)
            .onReceive(convOutput?.$text.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()) { _ in
                persistLiveTextStartIfNeeded()
            }
    }

    @ViewBuilder
    private func content(output: ConversationOutput?) -> some View {
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
    }

    private func refreshMissedResponse() async {
        guard let conv = effectiveConversation,
              let sessionId = conv.sessionId,
              let workingDir = conv.workingDirectory, !workingDir.isEmpty else { return }
        connection.syncHistory(sessionId: sessionId, workingDirectory: workingDir)
        try? await Task.sleep(for: .seconds(1))
    }

    private func persistLiveTextStartIfNeeded() {
        guard let output = convOutput,
              let liveId = output.liveMessageId,
              let conv = effectiveConversation,
              let message = conv.messages.first(where: { $0.id == liveId }) else { return }
        if message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !output.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.updateMessage(liveId, in: conv) {
                $0.text = output.text
            }
        }
    }
}
