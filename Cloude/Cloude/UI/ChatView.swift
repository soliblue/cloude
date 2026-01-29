//
//  ChatView.swift
//  Cloude
//
//  Main chat interface
//

import SwiftUI

struct ChatView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var store: ConversationStore
    @Environment(\.scenePhase) var scenePhase

    @State var inputText = ""
    @State var currentOutput = ""
    @State var currentToolCalls: [ToolCall] = []
    @State var currentRunStats: (durationMs: Int, costUsd: Double)?
    @State var scrollProxy: ScrollViewProxy?
    @State var hasClipboardContent = false
    @State var streamingToolCallsExpanded = false

    var messages: [ChatMessage] {
        store.currentConversation?.messages ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            inputArea
        }
        .onAppear {
            connection.onOutput = { text in
                currentOutput += text
            }
            connection.onToolCall = { name, input, toolId, parentToolId in
                currentToolCalls.append(ToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId))
            }
            connection.onSessionId = { [store] sessionId in
                if let conversation = store.currentConversation {
                    store.updateSessionId(conversation, sessionId: sessionId)
                }
            }
            connection.onRunStats = { durationMs, costUsd in
                currentRunStats = (durationMs, costUsd)
            }
        }
        .onChange(of: connection.agentState) { _, newState in
            if newState == .idle && !currentOutput.isEmpty {
                if scenePhase != .active {
                    NotificationManager.showCompletionNotification(preview: currentOutput)
                }
                if let conversation = store.currentConversation {
                    let message = ChatMessage(
                        isUser: false,
                        text: currentOutput.trimmingCharacters(in: .whitespacesAndNewlines),
                        toolCalls: currentToolCalls,
                        durationMs: currentRunStats?.durationMs,
                        costUsd: currentRunStats?.costUsd
                    )
                    store.addMessage(message, to: conversation)
                }
                currentOutput = ""
                currentToolCalls = []
                currentRunStats = nil
            }
            if newState == .running {
                currentRunStats = nil
                streamingToolCallsExpanded = false
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if !currentToolCalls.isEmpty || !currentOutput.isEmpty || currentRunStats != nil {
                        VStack(alignment: .leading, spacing: 0) {
                            if !currentToolCalls.isEmpty {
                                ToolCallsSection(toolCalls: currentToolCalls, isExpanded: $streamingToolCallsExpanded)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            if !currentOutput.isEmpty {
                                StreamingOutput(text: currentOutput)
                            }
                            if let stats = currentRunStats {
                                RunStatsView(durationMs: stats.durationMs, costUsd: stats.costUsd)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 4)
                            }
                        }
                        .id("streaming")
                    }
                }
            }
            .onAppear { scrollProxy = proxy }
            .onChange(of: connection.agentState) { old, new in
                if old == .idle && new == .running {
                    scrollToBottom()
                }
            }
        }
    }

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message Claude...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .onSubmit { sendMessage() }

            InputButtons(
                inputText: $inputText,
                hasClipboardContent: hasClipboardContent,
                agentState: connection.agentState,
                onPaste: pasteFromClipboard,
                onClear: { inputText = "" },
                onAbort: { connection.abort() },
                onSend: sendMessage
            )
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color(.systemBackground))
        .onAppear { checkClipboard() }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            checkClipboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkClipboard()
        }
    }
}
