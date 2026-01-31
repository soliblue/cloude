import SwiftUI
import UIKit
import CloudeShared

struct HeartbeatSheet: View {
    @ObservedObject var heartbeatStore: HeartbeatStore
    @ObservedObject var connection: ConnectionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) var scenePhase
    @State private var showIntervalPicker = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var inputText = ""
    @State private var selectedImageData: Data?

    private var convOutput: ConversationOutput {
        connection.output(for: heartbeatStore.conversation.id)
    }

    private let intervalOptions: [(label: String, minutes: Int)] = [
        ("Off", 0),
        ("5 min", 5),
        ("10 min", 10),
        ("30 min", 30),
        ("1 hour", 60),
        ("2 hours", 120),
        ("4 hours", 240),
        ("8 hours", 480),
        ("1 day", 1440)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProjectChatMessageList(
                    messages: heartbeatStore.conversation.messages + heartbeatStore.conversation.pendingMessages,
                    currentOutput: convOutput.text.isEmpty ? heartbeatStore.currentOutput : convOutput.text,
                    currentToolCalls: convOutput.toolCalls,
                    currentRunStats: convOutput.runStats,
                    scrollProxy: $scrollProxy,
                    agentState: (heartbeatStore.isRunning || convOutput.isRunning) ? .running : .idle,
                    conversationId: heartbeatStore.conversation.id
                )

                GlobalInputBar(
                    inputText: $inputText,
                    selectedImageData: $selectedImageData,
                    isConnected: connection.isConnected,
                    isWhisperReady: connection.isWhisperReady,
                    onSend: sendMessage,
                    onTranscribe: transcribeAudio
                )
            }
            .background(.ultraThinMaterial)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Heartbeat")
                            .font(.headline)
                        if heartbeatStore.isRunning || convOutput.isRunning {
                            Text("Running...")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else {
                            Text("Last: \(heartbeatStore.lastTriggeredDisplayText)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: triggerHeartbeat) {
                            Image(systemName: "bolt.heart")
                        }
                        .disabled(heartbeatStore.isRunning)

                        Divider()
                            .frame(height: 20)

                        Button(action: { showIntervalPicker = true }) {
                            intervalLabel
                        }
                    }
                }
            }
            .confirmationDialog("Heartbeat Interval", isPresented: $showIntervalPicker, titleVisibility: .visible) {
                ForEach(intervalOptions, id: \.minutes) { option in
                    Button(option.label) {
                        let minutes = option.minutes == 0 ? nil : option.minutes
                        heartbeatStore.intervalMinutes = minutes
                        connection.send(.setHeartbeatInterval(minutes: minutes))
                    }
                }
            }
            .onAppear {
                connection.send(.markHeartbeatRead)
                heartbeatStore.markRead()
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
        .presentationBackground(.ultraThinMaterial)
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

    @ViewBuilder
    private var intervalLabel: some View {
        if heartbeatStore.intervalMinutes == nil {
            Image(systemName: "clock.badge.xmark")
        } else {
            Text(heartbeatStore.intervalDisplayText)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private func triggerHeartbeat() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        print("[HeartbeatSheet] Triggering heartbeat")
        heartbeatStore.recordTrigger()
        connection.send(.triggerHeartbeat)
        heartbeatStore.isRunning = true
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageBase64 = selectedImageData?.base64EncodedString()
        guard !text.isEmpty || imageBase64 != nil else { return }

        let isRunning = heartbeatStore.isRunning || convOutput.isRunning

        if isRunning {
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: imageBase64)
            heartbeatStore.conversation.pendingMessages.append(userMessage)
            heartbeatStore.save()
        } else {
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: imageBase64)
            heartbeatStore.conversation.messages.append(userMessage)
            heartbeatStore.save()

            connection.sendChat(
                text,
                workingDirectory: nil,
                sessionId: heartbeatStore.conversation.sessionId,
                isNewSession: heartbeatStore.conversation.sessionId == nil,
                conversationId: heartbeatStore.conversation.id,
                imageBase64: imageBase64,
                conversationName: "Heartbeat",
                conversationSymbol: "heart.fill"
            )
            heartbeatStore.isRunning = true
        }

        inputText = ""
        selectedImageData = nil
    }

    private func transcribeAudio(_ audioData: Data) {
        connection.transcribe(audioBase64: audioData.base64EncodedString())
    }
}
