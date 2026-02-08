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
    @State private var attachedImages: [AttachedImage] = []
    @State private var isRefreshing = false
    @State private var currentEffort: EffortLevel?
    @State private var currentModel: ModelSelection?

    private var heartbeat: Conversation {
        conversationStore.heartbeatConversation
    }

    private var convOutput: ConversationOutput {
        connection.output(for: Heartbeat.conversationId)
    }

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
                    attachedImages: $attachedImages,
                    suggestions: .constant([]),
                    isConnected: connection.isConnected,
                    isWhisperReady: connection.isWhisperReady,
                    isTranscribing: connection.isTranscribing,
                    isRunning: convOutput.isRunning,
                    skills: connection.skills,
                    fileSearchResults: [],
                    conversationDefaultEffort: nil,
                    conversationDefaultModel: nil,
                    onSend: sendMessage,
                    onStop: { connection.abort(conversationId: Heartbeat.conversationId) },
                    onTranscribe: transcribeAudio,
                    onFileSearch: nil,
                    currentEffort: $currentEffort,
                    currentModel: $currentModel
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

                        Button {
                            guard !isRefreshing else { return }
                            isRefreshing = true
                            guard let workingDir = connection.defaultWorkingDirectory else {
                                isRefreshing = false
                                return
                            }
                            connection.syncHistory(sessionId: Heartbeat.sessionId, workingDirectory: workingDir)
                            Task {
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                isRefreshing = false
                            }
                        } label: {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isRefreshing)

                        Divider()
                            .frame(height: 20)

                        Button(action: { showIntervalPicker = true }) {
                            intervalLabel
                        }
                    }
                }
            }
            .confirmationDialog("Heartbeat Interval", isPresented: $showIntervalPicker, titleVisibility: .visible) {
                ForEach(HeartbeatConfig.intervalOptions, id: \.minutes) { option in
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
                    conversationStore.replayQueuedMessages(conversation: heartbeat, connection: connection)
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
        conversationStore.finalizeStreamingMessage(output: convOutput, conversation: heartbeat)
        conversationStore.replayQueuedMessages(conversation: heartbeat, connection: connection)
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
        let allImagesBase64 = ImageEncoder.encodeFullImages(attachedImages)
        let thumbnails = ImageEncoder.encodeThumbnails(attachedImages)
        guard !text.isEmpty || allImagesBase64 != nil else { return }

        if convOutput.isRunning || !connection.isAuthenticated {
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: thumbnails?.first, imageThumbnails: thumbnails)
            conversationStore.queueMessage(userMessage, to: heartbeat)
        } else {
            let userMessage = ChatMessage(isUser: true, text: text, imageBase64: thumbnails?.first, imageThumbnails: thumbnails)
            conversationStore.addMessage(userMessage, to: heartbeat)

            connection.sendChat(
                text,
                workingDirectory: nil,
                sessionId: Heartbeat.sessionId,
                isNewSession: false,
                conversationId: Heartbeat.conversationId,
                imagesBase64: allImagesBase64,
                conversationName: "Heartbeat",
                conversationSymbol: "heart.fill"
            )
        }

        inputText = ""
        attachedImages = []
    }

    private func transcribeAudio(_ audioData: Data) {
        connection.transcribe(audioBase64: audioData.base64EncodedString())
    }
}
