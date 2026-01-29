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
    @State private var currentOutput = ""
    @State private var currentToolCalls: [ToolCall] = []
    @State private var currentRunStats: (durationMs: Int, costUsd: Double)?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var hasClipboardContent = false
    @State private var streamingToolCallsExpanded = false

    init(connection: ConnectionManager, store: ProjectStore, project: Project? = nil, conversation: Conversation? = nil, isCompact: Bool = false, showHeader: Bool = false, onSelectConversation: (() -> Void)? = nil) {
        self.connection = connection
        self.store = store
        self.project = project
        self.conversation = conversation
        self.isCompact = isCompact
        self.showHeader = showHeader
        self.onSelectConversation = onSelectConversation
    }

    private var effectiveProject: Project? {
        project ?? store.currentProject
    }

    private var effectiveConversation: Conversation? {
        conversation ?? store.currentConversation
    }

    private var messages: [ChatMessage] {
        effectiveConversation?.messages ?? []
    }

    var body: some View {
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
                currentOutput: currentOutput,
                currentToolCalls: currentToolCalls,
                currentRunStats: isCompact ? nil : currentRunStats,
                scrollProxy: $scrollProxy,
                streamingToolCallsExpanded: $streamingToolCallsExpanded,
                agentState: connection.agentState
            )
            Divider()
            ProjectChatInputArea(
                inputText: $inputText,
                hasClipboardContent: hasClipboardContent,
                agentState: connection.agentState,
                isConnected: connection.isAuthenticated,
                isCompact: isCompact,
                onSend: sendMessage,
                onAbort: { connection.abort() }
            )
        }
        .onAppear { setupCallbacks() }
        .onChange(of: connection.agentState) { _, newState in
            handleStateChange(newState)
        }
        .onAppear { checkClipboard() }
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            checkClipboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkClipboard()
        }
    }

    private func setupCallbacks() {
        connection.onOutput = { text in
            currentOutput += text
        }
        connection.onToolCall = { name, input, toolId, parentToolId in
            currentToolCalls.append(ToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId))
        }
        connection.onSessionId = { [store, project, conversation] sessionId in
            let proj = project ?? store.currentProject
            let conv = conversation ?? store.currentConversation
            if let proj = proj, let conv = conv {
                store.updateSessionId(conv, in: proj, sessionId: sessionId)
            }
        }
        connection.onRunStats = { durationMs, costUsd in
            currentRunStats = (durationMs, costUsd)
        }
    }

    private func handleStateChange(_ newState: AgentState) {
        if newState == .running {
            currentRunStats = nil
            streamingToolCallsExpanded = false
        }

        guard newState == .idle, !currentOutput.isEmpty else { return }

        if scenePhase != .active {
            NotificationManager.showCompletionNotification(preview: currentOutput)
        }

        if let proj = effectiveProject, let conv = effectiveConversation {
            let message = ChatMessage(
                isUser: false,
                text: currentOutput.trimmingCharacters(in: .whitespacesAndNewlines),
                toolCalls: currentToolCalls,
                durationMs: currentRunStats?.durationMs,
                costUsd: currentRunStats?.costUsd
            )
            store.addMessage(message, to: conv, in: proj)
        }
        currentOutput = ""
        currentToolCalls = []
        currentRunStats = nil
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
        connection.sendChat(text, workingDirectory: workingDir, sessionId: conv.sessionId, isNewSession: isNewSession)
        inputText = ""
    }

    private func checkClipboard() {
        hasClipboardContent = UIPasteboard.general.hasStrings
    }
}
