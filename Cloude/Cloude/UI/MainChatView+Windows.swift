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
                        let newConv = conversationStore.newConversation(workingDirectory: workingDir)
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
            }
        }
    }

    func windowHeader(for window: ChatWindow, conversation: Conversation?) -> some View {
        HStack(spacing: 9) {
            Button(action: {
                windowManager.setActive(window.id)
                editingWindow = window
            }) {
                ConversationInfoLabel(
                    conversation: conversation,
                    showCost: true,
                    placeholderText: "Select chat..."
                )
                .padding(.horizontal, 7)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)

            Spacer()

            if let conv = conversation, conv.sessionId != nil {
                Button(action: {
                    windowManager.setActive(window.id)
                    if let newConv = conversationStore.duplicateConversation(conv) {
                        windowManager.linkToCurrentConversation(window.id, conversation: newConv)
                    }
                }) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(7)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 20)
            }

            Button(action: {
                windowManager.setActive(window.id)
                refreshConversation(for: window)
            }) {
                if let sid = window.conversation(in: conversationStore)?.sessionId,
                   refreshingSessionIds.contains(sid) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 15, height: 15)
                        .padding(7)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(7)
                }
            }
            .buttonStyle(.plain)
            .disabled(
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
                    .padding(7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .background(Color.oceanSecondary)
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
        connection.syncHistory(sessionId: sessionId, workingDirectory: workingDir)
    }
}

