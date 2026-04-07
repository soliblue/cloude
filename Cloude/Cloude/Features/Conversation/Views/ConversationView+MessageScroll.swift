import SwiftUI
import Combine
import CloudeShared

extension ChatMessageList {
    var scrollableContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    messageListSection(viewportHeight: scrollViewportHeight)
                    queuedMessagesSection
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: scrollViewportHeight, alignment: .top)
        }
        .defaultScrollAnchor(.bottom)
        .coordinateSpace(name: "chatScroll")
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background {
            GeometryReader { geo in
                Color.clear.onAppear { scrollViewportHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, h in scrollViewportHeight = h }
            }
        }
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
        .onReceive(connection?.events.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()) { (event: ConnectionEvent) in
            if case .historySync = event { refreshingMessageId = nil }
            if case .historySyncError = event { refreshingMessageId = nil }
        }
        .task(id: conversationId) {
            if !messages.isEmpty || conversationId == nil || conversation?.sessionId == nil {
                isInitialLoad = false
            }
        }
    }

    func messageListSection(viewportHeight: CGFloat) -> some View {
        ForEach(messages) { message in
            if let output = conversationOutput {
                ObservedMessageBubble(
                    message: message,
                    output: output,
                    skills: connection?.skills ?? [],
                    onRefresh: message.isUser ? nil : { refreshMessage(message) },
                    isRefreshing: refreshingMessageId == message.id,
                    onSelectToolDetail: { selectedToolDetail = $0 }
                )
                .equatable()
                .readingProgress(
                    isAssistant: !message.isUser,
                    viewportHeight: viewportHeight
                )
                .id("\(message.id.uuidString)-\(fontSizeStep)")
            } else {
                MessageBubble(
                    message: message,
                    skills: connection?.skills ?? [],
                    onRefresh: message.isUser ? nil : { refreshMessage(message) },
                    isRefreshing: refreshingMessageId == message.id,
                    onSelectToolDetail: { selectedToolDetail = $0 }
                )
                .readingProgress(
                    isAssistant: !message.isUser,
                    viewportHeight: viewportHeight
                )
                .id("\(message.id.uuidString)-\(fontSizeStep)")
            }
        }
    }

    func refreshMessage(_ message: ChatMessage) {
        guard let conversation, let sessionId = conversation.sessionId,
              let workingDir = conversation.workingDirectory, !workingDir.isEmpty else { return }
        refreshingMessageId = message.id
        connection?.syncHistory(sessionId: sessionId, workingDirectory: workingDir, environmentId: conversation.environmentId)
    }

    var queuedMessagesSection: some View {
        ForEach(queuedMessages) { message in
            QueuedBubble(message: message, skills: connection?.skills ?? []) {
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
