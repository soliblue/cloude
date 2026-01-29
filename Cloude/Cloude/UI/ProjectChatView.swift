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
    var onSelectConversation: (() -> Void)?

    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @State private var hasClipboardContent = false
    @State private var lastCompletedOutput: String = ""

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
                agentState: isThisConversationRunning ? .running : .idle
            )
            Divider()
            ProjectChatInputArea(
                inputText: $inputText,
                hasClipboardContent: hasClipboardContent,
                agentState: isThisConversationRunning ? .running : .idle,
                isConnected: connection.isAuthenticated,
                isCompact: isCompact,
                onSend: sendMessage,
                onAbort: { connection.abort() }
            )
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
        guard output.text != lastCompletedOutput else { return }
        guard output.isRunning == false else { return }

        lastCompletedOutput = output.text

        if scenePhase != .active {
            NotificationManager.showCompletionNotification(preview: output.text)
        }

        if let proj = effectiveProject, var conv = effectiveConversation {
            if let newSessionId = output.newSessionId {
                store.updateSessionId(conv, in: proj, sessionId: newSessionId)
                conv = store.projects.first { $0.id == proj.id }?.conversations.first { $0.id == conv.id } ?? conv
            }

            let message = ChatMessage(
                isUser: false,
                text: output.text.trimmingCharacters(in: .whitespacesAndNewlines),
                toolCalls: output.toolCalls,
                durationMs: output.runStats?.durationMs,
                costUsd: output.runStats?.costUsd
            )
            store.addMessage(message, to: conv, in: proj)
            output.reset()
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

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

        let userMessage = ChatMessage(isUser: true, text: text)
        store.addMessage(userMessage, to: conv, in: proj)

        let isNewSession = conv.sessionId == nil
        let workingDir = proj.rootDirectory.isEmpty ? nil : proj.rootDirectory
        connection.sendChat(text, workingDirectory: workingDir, sessionId: conv.sessionId, isNewSession: isNewSession, conversationId: conv.id)
        inputText = ""
    }

    private func checkClipboard() {
        hasClipboardContent = UIPasteboard.general.hasStrings
    }
}
