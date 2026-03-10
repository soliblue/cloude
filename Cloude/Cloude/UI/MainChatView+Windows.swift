import SwiftUI

extension MainChatView {
    @ViewBuilder
    func pagedWindowContent(for window: ChatWindow) -> some View {
        let conversation = window.conversation(in: conversationStore)

        VStack(spacing: 0) {
            windowHeader(for: window, conversation: conversation)

            switch window.type {
            case .chat:
                ConversationView(
                    connection: connection,
                    store: conversationStore,
                    environmentStore: environmentStore,
                    conversation: conversation,
                    window: window,
                    windowManager: windowManager,
                    isCompact: false,
                    isKeyboardVisible: isKeyboardVisible,
                    onInteraction: { dismissKeyboard() },
                    onSelectRecentConversation: { conv in
                        windowManager.linkToCurrentConversation(window.id, conversation: conv)
                    },
                    onNewConversation: {
                        let workingDir = activeWindowWorkingDirectory()
                        let newConv = conversationStore.newConversation(workingDirectory: workingDir, environmentId: activeWindowEnvironmentId())
                        windowManager.linkToCurrentConversation(window.id, conversation: newConv)
                    }
                )
            case .files:
                FileBrowserView(
                    connection: connection,
                    rootPath: conversation?.workingDirectory
                )
            case .gitChanges:
                GitChangesView(
                    connection: connection,
                    rootPath: conversation?.workingDirectory
                )
            case .terminal:
                TerminalView(
                    connection: connection,
                    rootPath: conversation?.workingDirectory,
                    environmentId: conversation?.environmentId,
                    terminalId: window.id.uuidString
                )
            }
        }
    }

    func windowHeader(for window: ChatWindow, conversation: Conversation?) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(WindowType.allCases.enumerated()), id: \.element) { index, type in
                    if index > 0 {
                        Divider()
                            .frame(height: 20)
                    }
                    Button(action: {
                        windowManager.setWindowType(window.id, type: type)
                    }) {
                        Image(systemName: type.icon)
                            .font(.system(size: 15, weight: window.type == type ? .semibold : .regular))
                            .foregroundColor(window.type == type ? .accentColor : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            if let envId = conversation?.environmentId,
               let env = environmentStore.environments.first(where: { $0.id == envId }) {
                Image(systemName: env.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Circle())
            }

            Spacer()

            HStack(spacing: 0) {
                Button(action: {
                    if let conv = conversation {
                        exportConversation(conv)
                        exportCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { exportCopied = false }
                    }
                }) {
                    Image(systemName: exportCopied ? "checkmark" : "square.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(exportCopied ? .green : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .disabled(conversation == nil || conversation?.messages.isEmpty == true)

                Divider()
                    .frame(height: 20)

                Button(action: {
                    if let conv = conversation, conv.sessionId != nil {
                        windowManager.setActive(window.id)
                        if let newConv = conversationStore.duplicateConversation(conv) {
                            windowManager.linkToCurrentConversation(window.id, conversation: newConv)
                        }
                    }
                }) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .disabled(conversation?.sessionId == nil)

                Divider()
                    .frame(height: 20)

                Button(action: {
                    windowManager.setActive(window.id)
                    refreshTrigger.toggle()
                    refreshConversation(for: window)
                }) {
                    if let sid = window.conversation(in: conversationStore)?.sessionId,
                       refreshingSessionIds.contains(sid) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 15, height: 15)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .symbolEffect(.rotate, options: .nonRepeating, value: refreshTrigger)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                }
                .buttonStyle(.plain)
                .disabled(
                    environmentDisconnected(for: conversation) ||
                    window.conversationId.map({ connection.output(for: $0).isRunning }) ?? false ||
                        window.conversationId
                            .flatMap({ conversationStore.conversation(withId: $0)?.sessionId })
                            .map({ refreshingSessionIds.contains($0) }) ?? false
                )

                Divider()
                    .frame(height: 20)

                Button(action: {
                    windowManager.setActive(window.id)
                    windowManager.removeWindow(window.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.top, 0)
        .padding(.bottom, 7)
        .background(Color.oceanSecondary)
    }

    private func exportConversation(_ conversation: Conversation) {
        var lines: [String] = []
        let messages = conversationStore.messages(for: conversation)

        for message in messages {
            if message.isUser {
                lines.append("**User**: \(message.text)")
            } else {
                var parts: [String] = []
                let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { parts.append(text) }
                for tool in message.toolCalls {
                    let input = tool.input ?? ""
                    parts.append("> **\(tool.name)**: \(input)")
                }
                lines.append(parts.joined(separator: "\n\n"))
            }
        }

        let markdown = lines.joined(separator: "\n\n---\n\n")
        UIPasteboard.general.string = markdown
    }

    func environmentDisconnected(for conversation: Conversation?) -> Bool {
        if let envId = conversation?.environmentId {
            return !(connection.connection(for: envId)?.isAuthenticated ?? false)
        }
        return false
    }

    private func refreshConversation(for window: ChatWindow) {
        guard let convId = window.conversationId,
              let conv = conversationStore.conversation(withId: convId),
              let sessionId = conv.sessionId,
              let workingDir = conv.workingDirectory, !workingDir.isEmpty else { return }
        refreshingSessionIds.insert(sessionId)
        let messages = conversationStore.messages(for: conv)
        if let lastUserIndex = messages.lastIndex(where: { $0.isUser }) {
            conversationStore.truncateMessages(for: conv, from: lastUserIndex + 1)
        }
        connection.syncHistory(sessionId: sessionId, workingDirectory: workingDir, environmentId: conv.environmentId)
    }
}

