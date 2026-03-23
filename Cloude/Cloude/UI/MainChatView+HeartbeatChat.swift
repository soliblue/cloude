import SwiftUI
import CloudeShared

struct HeartbeatChatView: View {
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var connection: ConnectionManager
    @Binding var inputText: String
    @Binding var attachedImages: [AttachedImage]
    var isKeyboardVisible: Bool
    private var heartbeat: Conversation {
        conversationStore.heartbeatConversation
    }

    private var convOutput: ConversationOutput {
        connection.output(for: Heartbeat.conversationId)
    }

    var body: some View {
        ChatMessageList(
            messages: heartbeat.messages,
            queuedMessages: heartbeat.pendingMessages,
            agentState: convOutput.isRunning ? .running : .idle,
            conversationId: Heartbeat.conversationId,
            onDeleteQueued: { messageId in
                conversationStore.removePendingMessage(messageId, from: heartbeat)
            },
            conversationOutput: convOutput
        )
        .onAppear {
            if !convOutput.isRunning {
                conversationStore.replayQueuedMessages(conversation: heartbeat, connection: connection)
            }
        }
        .onChange(of: convOutput.isRunning) { wasRunning, isRunning in
            if wasRunning && !isRunning {
                handleChatCompletion()
            }
        }
    }

    private func handleChatCompletion() {
        conversationStore.finalizeStreamingMessage(output: convOutput, conversation: heartbeat)
        conversationStore.replayQueuedMessages(conversation: heartbeat, connection: connection)
    }
}
