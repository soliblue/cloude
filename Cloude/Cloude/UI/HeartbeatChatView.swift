//
//  HeartbeatChatView.swift
//  Cloude

import SwiftUI
import UIKit
import CloudeShared

struct HeartbeatChatView: View {
    @ObservedObject var heartbeatStore: HeartbeatStore
    @ObservedObject var connection: ConnectionManager
    @Binding var inputText: String
    @Binding var selectedImageData: Data?
    var isKeyboardVisible: Bool
    @State private var scrollProxy: ScrollViewProxy?

    private var convOutput: ConversationOutput {
        connection.output(for: Heartbeat.conversationId)
    }

    var body: some View {
        ProjectChatMessageList(
            messages: heartbeatStore.conversation.messages,
            queuedMessages: heartbeatStore.conversation.pendingMessages,
            currentOutput: convOutput.text,
            currentToolCalls: convOutput.toolCalls,
            currentRunStats: convOutput.runStats,
            scrollProxy: $scrollProxy,
            agentState: convOutput.isRunning ? .running : .idle,
            conversationId: Heartbeat.conversationId,
            onDeleteQueued: { messageId in
                heartbeatStore.conversation.pendingMessages.removeAll { $0.id == messageId }
                heartbeatStore.save()
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
            costUsd: convOutput.runStats?.costUsd
        )
        heartbeatStore.conversation.messages.append(message)
        heartbeatStore.conversation.lastMessageAt = Date()
        heartbeatStore.save()
        convOutput.reset()

        sendQueuedMessages()
    }

    private func sendQueuedMessages() {
        let pending = heartbeatStore.conversation.pendingMessages
        guard !pending.isEmpty else { return }

        heartbeatStore.conversation.pendingMessages = []

        for var msg in pending {
            msg.isQueued = false
            heartbeatStore.conversation.messages.append(msg)
        }
        heartbeatStore.save()

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
