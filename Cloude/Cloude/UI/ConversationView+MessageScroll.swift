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
            .frame(minHeight: scrollViewportHeight)
        }
        .defaultScrollAnchor(.bottom)
        .scrollPosition($scrollPos)
        .coordinateSpace(name: "chatScroll")
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background {
            GeometryReader { geo in
                Color.clear.onAppear { scrollViewportHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, h in scrollViewportHeight = h }
            }
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
        .onChange(of: messages.last?.id) { _, _ in
            guard messages.last?.isUser == true else { return }
            Task { @MainActor in
                await Task.yield()
                scrollPos.scrollTo(edge: .bottom)
            }
        }
        .onReceive(connection?.events.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()) { (event: ConnectionEvent) in
            if case .historySync = event { refreshingMessageId = nil }
            if case .historySyncError = event { refreshingMessageId = nil }
        }
        .task(id: conversationId) {
            if !messages.isEmpty {
                isInitialLoad = false
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            if isInitialLoad {
                isInitialLoad = false
            }
        }
    }

    func messageListSection(viewportHeight: CGFloat) -> some View {
        ForEach(messages) { message in
            if let output = conversationOutput, output.liveMessageId == message.id {
                ObservedMessageBubble(
                    message: message,
                    output: output,
                    skills: connection?.skills ?? [],
                    isCompact: isCompact,
                    onToggleCollapse: message.isUser ? nil : { toggleCollapse(message) }
                )
                .id("\(message.id)-\(message.isQueued)")
            } else {
                MessageBubble(
                    message: message,
                    skills: connection?.skills ?? [],
                    onRefresh: message.isUser ? nil : { refreshMessage(message) },
                    onToggleCollapse: message.isUser ? nil : { toggleCollapse(message) },
                    isRefreshing: refreshingMessageId == message.id
                )
                .readingProgress(
                    isAssistant: !message.isUser,
                    isCollapsed: message.isCollapsed,
                    viewportHeight: viewportHeight
                )
                .id("\(message.id)-\(message.isQueued)")
            }
        }
    }

    func toggleCollapse(_ message: ChatMessage) {
        if let conversation, let store = conversationStore {
            store.updateMessage(message.id, in: conversation) { $0.isCollapsed.toggle() }
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
            .id("\(message.id)-queued")
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
