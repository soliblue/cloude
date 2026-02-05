import SwiftUI
import UIKit
import CloudeShared

struct HeartbeatSheet: View {
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var connection: ConnectionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) var scenePhase
    @State private var showIntervalPicker = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var inputText = ""
    @State private var selectedImageData: Data?

    private var heartbeat: Conversation {
        conversationStore.heartbeatConversation
    }

    private var convOutput: ConversationOutput {
        connection.output(for: Heartbeat.conversationId)
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
                ChatMessageList(
                    messages: heartbeat.messages + heartbeat.pendingMessages,
                    currentOutput: convOutput.text,
                    currentToolCalls: convOutput.toolCalls,
                    currentRunStats: convOutput.runStats,
                    scrollProxy: $scrollProxy,
                    agentState: convOutput.isRunning ? .running : .idle,
                    conversationId: Heartbeat.conversationId
                )

                GlobalInputBar(
                    inputText: $inputText,
                    selectedImageData: $selectedImageData,
                    isConnected: connection.isConnected,
                    isWhisperReady: connection.isWhisperReady,
                    isTranscribing: connection.isTranscribing,
                    isRunning: convOutput.isRunning,
                    skills: connection.skills,
                    fileSearchResults: [],
                    onSend: sendMessage,
                    onStop: { connection.abort(conversationId: Heartbeat.conversationId) },
                    onTranscribe: transcribeAudio,
                    onFileSearch: nil
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
                        if convOutput.isRunning {
                            Text("Running...")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else {
                            Text("Last: \(conversationStore.heartbeatConfig.lastTriggeredDisplayText)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: triggerHeartbeat) {
                            Image(systemName: "bolt.heart.fill")
                                .font(.system(size: 13))
                                .foregroundColor(convOutput.isRunning ? .secondary : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(convOutput.isRunning ? Color.secondary.opacity(0.2) : Color.accentColor)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(convOutput.isRunning)

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
                        conversationStore.heartbeatConfig.intervalMinutes = minutes
                        connection.send(.setHeartbeatInterval(minutes: minutes))
                    }
                }
            }
            .onAppear {
                connection.send(.markHeartbeatRead)
                conversationStore.markHeartbeatRead()
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
        .presentationBackground(.ultraThinMaterial)
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

    @ViewBuilder
    private var intervalLabel: some View {
        if conversationStore.heartbeatConfig.intervalMinutes == nil {
            Image(systemName: "clock.badge.xmark")
        } else {
            Text(conversationStore.heartbeatConfig.intervalDisplayText)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    private func triggerHeartbeat() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        conversationStore.recordHeartbeatTrigger()
        connection.send(.triggerHeartbeat)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageBase64 = selectedImageData?.base64EncodedString()
        guard !text.isEmpty || imageBase64 != nil else { return }

        if convOutput.isRunning {
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: imageBase64)
            conversationStore.queueMessage(userMessage, to: heartbeat)
        } else {
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: imageBase64)
            conversationStore.addMessage(userMessage, to: heartbeat)

            connection.sendChat(
                text,
                workingDirectory: nil,
                sessionId: Heartbeat.sessionId,
                isNewSession: false,
                conversationId: Heartbeat.conversationId,
                imageBase64: imageBase64,
                conversationName: "Heartbeat",
                conversationSymbol: "heart.fill"
            )
        }

        inputText = ""
        selectedImageData = nil
    }

    private func transcribeAudio(_ audioData: Data) {
        connection.transcribe(audioBase64: audioData.base64EncodedString())
    }
}
