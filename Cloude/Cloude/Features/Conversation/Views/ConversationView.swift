import SwiftUI
import Combine
import CloudeShared

struct ConversationView: View {
    let environmentStore: EnvironmentStore
    let store: ConversationStore

    let conversation: Conversation?
    var window: Window?
    var windowManager: WindowManager?
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
        guard let conv = effectiveConversation else { return nil }
        return environmentStore.connection(for: conv.environmentId)?.output(for: conv.id)
    }

    var body: some View {
        let _ = NSLog("[STABILITY] ConversationView.body | msgs=\(messages.count) hasOutput=\(convOutput != nil) convId=\(effectiveConversation?.id.uuidString.prefix(6) ?? "nil")")
        Group {
            if let connection = effectiveConversation.flatMap({ environmentStore.connection(for: $0.environmentId) }) {
                EnvironmentConnectionObserver(connection: connection) { _ in
                    content(output: convOutput)
                }
            } else {
                content(output: convOutput)
            }
        }
        .onReceive(convOutput?.$text.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()) { _ in
            persistLiveTextStartIfNeeded()
        }
    }

    @ViewBuilder
    private func content(output: ConversationOutput?) -> some View {
        ChatMessageList(
            messages: messages,
            queuedMessages: queuedMessages,
            conversationId: effectiveConversation?.id,
            onInteraction: onInteraction,
            onDeleteQueued: { messageId in
                if let conv = effectiveConversation {
                    store.removePendingMessage(messageId, from: conv)
                }
            },
            conversation: effectiveConversation,
            conversationStore: store,
            window: window,
            windowManager: windowManager,
            onSelectConversation: onSelectRecentConversation,
            onSeeAllConversations: onSeeAllConversations,
            environmentStore: environmentStore,
            conversationOutput: output
        )
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
