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
        connection.output(for: heartbeatStore.conversation.id)
    }

    var body: some View {
        ProjectChatMessageList(
            messages: heartbeatStore.conversation.messages + heartbeatStore.conversation.pendingMessages,
            currentOutput: convOutput.text.isEmpty ? heartbeatStore.currentOutput : convOutput.text,
            currentToolCalls: convOutput.toolCalls,
            currentRunStats: convOutput.runStats,
            scrollProxy: $scrollProxy,
            agentState: (heartbeatStore.isRunning || convOutput.isRunning) ? .running : .idle,
            conversationId: heartbeatStore.conversation.id
        )
        .onAppear {
            if !heartbeatStore.isRunning && !convOutput.isRunning {
                sendQueuedMessages()
            }
        }
        .onChange(of: convOutput.isRunning) { wasRunning, isRunning in
            if wasRunning && !isRunning && !convOutput.text.isEmpty {
                handleUserChatCompletion()
            }
        }
        .onChange(of: heartbeatStore.isRunning) { wasRunning, isRunning in
            if wasRunning && !isRunning && !convOutput.isRunning {
                sendQueuedMessages()
            }
        }
        .onChange(of: convOutput.newSessionId) { _, newId in
            if let sessionId = newId {
                heartbeatStore.conversation.sessionId = sessionId
                heartbeatStore.save()
            }
        }
    }

    private func handleUserChatCompletion() {
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
        heartbeatStore.isRunning = false

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
            sessionId: heartbeatStore.conversation.sessionId,
            isNewSession: heartbeatStore.conversation.sessionId == nil,
            conversationId: heartbeatStore.conversation.id,
            conversationName: "Heartbeat",
            conversationSymbol: "heart.fill"
        )
        heartbeatStore.isRunning = true
    }
}
