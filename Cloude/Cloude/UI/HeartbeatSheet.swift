//
//  HeartbeatSheet.swift
//  Cloude
//

import SwiftUI
import UIKit

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
                    messages: heartbeatStore.conversation.messages,
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
                    hasClipboardContent: UIPasteboard.general.hasStrings,
                    isConnected: connection.isConnected,
                    isWhisperReady: connection.isWhisperReady,
                    onSend: sendMessage,
                    onTranscribe: transcribeAudio
                )
            }
            .navigationTitle("Heartbeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
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
            }
            .onChange(of: convOutput.isRunning) { wasRunning, isRunning in
                if wasRunning && !isRunning && !convOutput.text.isEmpty {
                    handleUserChatCompletion()
                }
            }
            .onChange(of: convOutput.newSessionId) { _, newId in
                if let sessionId = newId {
                    heartbeatStore.conversation.sessionId = sessionId
                    heartbeatStore.save()
                }
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
        print("[HeartbeatSheet] Triggering heartbeat")
        connection.send(.triggerHeartbeat)
        heartbeatStore.isRunning = true
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(isUser: true, text: text)
        heartbeatStore.conversation.messages.append(userMessage)
        heartbeatStore.save()

        connection.send(.chat(
            message: text,
            workingDirectory: nil,
            sessionId: heartbeatStore.conversation.sessionId,
            isNewSession: heartbeatStore.conversation.sessionId == nil,
            imageBase64: selectedImageData?.base64EncodedString(),
            conversationId: heartbeatStore.conversation.id.uuidString
        ))

        heartbeatStore.isRunning = true
        inputText = ""
        selectedImageData = nil
    }

    private func transcribeAudio(_ audioData: Data) {
        connection.transcribe(audioBase64: audioData.base64EncodedString())
    }
}
