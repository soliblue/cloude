//
//  ProjectChatView.swift
//  Cloude
//
//  Chat interface that works with projects
//

import SwiftUI

struct ProjectChatView: View {
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var store: ProjectStore
    @Environment(\.scenePhase) var scenePhase

    let project: Project?
    let conversation: Conversation?
    var isCompact: Bool = false
    var showHeader: Bool = false
    var showInput: Bool = true
    var onSelectConversation: (() -> Void)?
    var onInputFocus: (() -> Void)?
    var onInteraction: (() -> Void)?

    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @State private var hasClipboardContent = false
    @State private var selectedImageData: Data?

    private var effectiveProject: Project? {
        project ?? store.currentProject
    }

    private var effectiveConversation: Conversation? {
        conversation ?? store.currentConversation
    }

    private var messages: [ChatMessage] {
        effectiveConversation?.messages ?? []
    }

    private var convOutput: ConversationOutput? {
        guard let convId = effectiveConversation?.id else { return nil }
        return connection.output(for: convId)
    }

    private var isThisConversationRunning: Bool {
        guard let convId = effectiveConversation?.id else { return false }
        return connection.runningConversationId == convId
    }

    private var pendingCount: Int {
        guard let proj = effectiveProject, let conv = effectiveConversation else { return 0 }
        return store.pendingMessageCount(in: conv, in: proj)
    }

    var body: some View {
        let output = convOutput

        VStack(spacing: 0) {
            if showHeader {
                PaneHeaderView(
                    project: effectiveProject,
                    conversation: effectiveConversation,
                    onSelectConversation: onSelectConversation
                )
                Divider()
            }
            ProjectChatMessageList(
                messages: messages,
                currentOutput: output?.text ?? "",
                currentToolCalls: output?.toolCalls ?? [],
                currentRunStats: isCompact ? nil : output?.runStats,
                scrollProxy: $scrollProxy,
                agentState: isThisConversationRunning ? .running : .idle,
                onRefresh: refreshMissedResponse,
                onInteraction: onInteraction
            )
            if showInput {
                Divider()
                ProjectChatInputArea(
                    inputText: $inputText,
                    selectedImageData: $selectedImageData,
                    hasClipboardContent: hasClipboardContent,
                    agentState: isThisConversationRunning ? .running : .idle,
                    isConnected: connection.isAuthenticated,
                    isCompact: isCompact,
                    pendingCount: pendingCount,
                    onSend: sendMessage,
                    onInputFocus: onInputFocus
                )
            }
        }
        .onChange(of: connection.agentState) { oldState, newState in
            if oldState == .running && newState == .idle {
                handleCompletion()
            }
        }
        .onAppear { checkClipboard() }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            checkClipboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkClipboard()
        }
    }

    private func handleCompletion() {
        guard let convId = effectiveConversation?.id else { return }
        guard let output = convOutput else { return }
        guard !output.text.isEmpty else { return }
        guard output.isRunning == false else { return }

        if scenePhase != .active {
            NotificationManager.showCompletionNotification(preview: output.text)
        }

        if let proj = effectiveProject, var conv = effectiveConversation {
            if let newSessionId = output.newSessionId {
                store.updateSessionId(conv, in: proj, sessionId: newSessionId)
                conv = store.projects.first { $0.id == proj.id }?.conversations.first { $0.id == conv.id } ?? conv
            }

            let messageId = UUID()
            if output.lastSavedMessageId == messageId { return }

            let message = ChatMessage(
                isUser: false,
                text: output.text.trimmingCharacters(in: .whitespacesAndNewlines),
                toolCalls: output.toolCalls,
                durationMs: output.runStats?.durationMs,
                costUsd: output.runStats?.costUsd
            )

            let freshConv = store.projects.first { $0.id == proj.id }?.conversations.first { $0.id == conv.id } ?? conv
            let isDuplicate = freshConv.messages.contains { !$0.isUser && $0.text == message.text && abs($0.timestamp.timeIntervalSinceNow) < 5 }
            guard !isDuplicate else {
                output.reset()
                return
            }

            output.lastSavedMessageId = messageId
            store.addMessage(message, to: conv, in: proj)
            output.reset()

            sendQueuedMessages(proj: proj, conv: conv)
        }
    }

    private func sendQueuedMessages(proj: Project, conv: Conversation) {
        let freshConv = store.projects.first { $0.id == proj.id }?.conversations.first { $0.id == conv.id } ?? conv
        let pending = store.popPendingMessages(from: freshConv, in: proj)
        guard !pending.isEmpty else { return }

        for var msg in pending {
            msg.isQueued = false
            store.addMessage(msg, to: freshConv, in: proj)
        }

        let combinedText = pending.map { $0.text }.joined(separator: "\n\n")
        let updatedConv = store.projects.first { $0.id == proj.id }?.conversations.first { $0.id == conv.id } ?? conv
        let workingDir = proj.rootDirectory.isEmpty ? nil : proj.rootDirectory
        connection.sendChat(combinedText, workingDirectory: workingDir, sessionId: updatedConv.sessionId, isNewSession: false, conversationId: updatedConv.id)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageBase64 = selectedImageData?.base64EncodedString()
        guard !text.isEmpty || imageBase64 != nil else { return }

        var proj = effectiveProject
        if proj == nil {
            proj = store.createProject(name: "Default Project")
        }
        guard let proj = proj else { return }

        var conv = effectiveConversation
        if conv == nil {
            conv = store.newConversation(in: proj)
        }
        guard let conv = conv else { return }

        if isThisConversationRunning {
            let userMessage = ChatMessage(isUser: true, text: text, isQueued: true, imageBase64: imageBase64)
            store.queueMessage(userMessage, to: conv, in: proj)
            inputText = ""
            selectedImageData = nil
            return
        }

        let userMessage = ChatMessage(isUser: true, text: text, imageBase64: imageBase64)
        store.addMessage(userMessage, to: conv, in: proj)

        let isNewSession = conv.sessionId == nil
        let workingDir = proj.rootDirectory.isEmpty ? nil : proj.rootDirectory
        connection.sendChat(text, workingDirectory: workingDir, sessionId: conv.sessionId, isNewSession: isNewSession, conversationId: conv.id, imageBase64: imageBase64)
        inputText = ""
        selectedImageData = nil
    }

    private func checkClipboard() {
        hasClipboardContent = UIPasteboard.general.hasStrings
    }

    private func refreshMissedResponse() async {
        guard let sessionId = effectiveConversation?.sessionId else { return }
        connection.requestMissedResponse(sessionId: sessionId)
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}
