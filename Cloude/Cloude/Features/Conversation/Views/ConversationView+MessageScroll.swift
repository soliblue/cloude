import SwiftUI
import Combine
import CloudeShared

extension ChatMessageList {
    var scrollableContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                messageListSection
                queuedMessagesSection
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $selectedToolDetail) { item in
            ToolDetailSheet(toolCall: item.toolCall, children: item.children)
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { onInteraction?() }
        )
        .onAppear {
            if !messages.isEmpty && isInitialLoad {
                isInitialLoad = false
            }
        }
        .onChange(of: messages.count) { old, new in
            if new > 0 && isInitialLoad {
                isInitialLoad = false
            }
        }
        .onReceive(environmentStore?.events.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()) { (event: ConnectionEvent) in
            if case .historySync = event { refreshingMessageId = nil }
            if case .historySyncError = event { refreshingMessageId = nil }
        }
        .task(id: conversationId) {
            if !messages.isEmpty || conversationId == nil || conversation?.sessionId == nil {
                isInitialLoad = false
            }
        }
    }

    private var conversationSkills: [Skill] {
        guard let conversation else { return [] }
        return environmentStore?.connection(for: conversation.environmentId)?.skills ?? []
    }

    var messageListSection: some View {
        ForEach(messages) { message in
            if let output = conversationOutput {
                ObservedMessageBubble(
                    message: message,
                    output: output,
                    skills: conversationSkills,
                    onRefresh: message.isUser ? nil : { refreshMessage(message) },
                    isRefreshing: refreshingMessageId == message.id,
                    onSelectToolDetail: { selectedToolDetail = $0 }
                )
                .equatable()
                .id("\(message.id.uuidString)-\(fontSizeStep)")
            } else {
                MessageBubble(
                    message: message,
                    skills: conversationSkills,
                    onRefresh: message.isUser ? nil : { refreshMessage(message) },
                    isRefreshing: refreshingMessageId == message.id,
                    onSelectToolDetail: { selectedToolDetail = $0 }
                )
                .id("\(message.id.uuidString)-\(fontSizeStep)")
            }
        }
    }

    func refreshMessage(_ message: ChatMessage) {
        guard let conversation, let sessionId = conversation.sessionId,
              let workingDir = conversation.workingDirectory, !workingDir.isEmpty else { return }
        refreshingMessageId = message.id
        environmentStore?.connection(for: conversation.environmentId)?.syncHistory(sessionId: sessionId, workingDirectory: workingDir)
    }

    var queuedMessagesSection: some View {
        ForEach(queuedMessages) { message in
            QueuedBubble(message: message, skills: conversationSkills) {
                onDeleteQueued?(message.id)
            }
            .id("\(message.id.uuidString)-queued-\(fontSizeStep)")
        }
    }
}

struct QueuedBubble: View {
    let message: ChatMessage
    var skills: [Skill] = []
    let onDelete: () -> Void

    var body: some View {
        MessageBubble(message: message, skills: skills)
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}
