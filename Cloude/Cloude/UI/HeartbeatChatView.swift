import SwiftUI
import UIKit
import CloudeShared

struct HeartbeatChatView: View {
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var connection: ConnectionManager
    @Binding var inputText: String
    @Binding var selectedImageData: Data?
    var isKeyboardVisible: Bool
    @State private var scrollProxy: ScrollViewProxy?

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
            currentOutput: convOutput.text,
            currentToolCalls: convOutput.toolCalls,
            currentRunStats: convOutput.runStats,
            scrollProxy: $scrollProxy,
            agentState: convOutput.isRunning ? .running : .idle,
            conversationId: Heartbeat.conversationId,
            onDeleteQueued: { messageId in
                conversationStore.removePendingMessage(messageId, from: heartbeat)
            }
        )
        .onAppear {
            if !convOutput.isRunning {
                sendQueuedMessages()
            }
        }
        .onChange(of: convOutput.isRunning) { wasRunning, isRunning in
            if wasRunning && !isRunning && !convOutput.text.isEmpty {
                handleChatCompletion()
            }
        }
    }

    private func handleChatCompletion() {
        let message = ChatMessage(
            isUser: false,
            text: convOutput.text.trimmingCharacters(in: .whitespacesAndNewlines),
            toolCalls: convOutput.toolCalls,
            durationMs: convOutput.runStats?.durationMs,
            costUsd: convOutput.runStats?.costUsd,
            serverUUID: convOutput.messageUUID
        )
        conversationStore.addMessage(message, to: heartbeat)
        convOutput.reset()
        sendQueuedMessages()
    }

    private func sendQueuedMessages() {
        let pending = conversationStore.popPendingMessages(from: heartbeat)
        guard !pending.isEmpty else { return }

        for var msg in pending {
            msg.isQueued = false
            conversationStore.addMessage(msg, to: heartbeat)
        }

        let combinedText = pending.map { $0.text }.joined(separator: "\n\n")
        connection.sendChat(
            combinedText,
            workingDirectory: nil,
            sessionId: Heartbeat.sessionId,
            isNewSession: false,
            conversationId: Heartbeat.conversationId,
            conversationName: "Heartbeat",
            conversationSymbol: "heart.fill"
        )
    }
}
