import SwiftUI
import Combine
import CloudeShared

struct ChatMessageList: View {
    let messages: [ChatMessage]
    var queuedMessages: [ChatMessage] = []
    let currentOutput: String
    let currentToolCalls: [ToolCall]
    let currentRunStats: (durationMs: Int, costUsd: Double, model: String?)?
    let agentState: AgentState
    let conversationId: UUID?
    var isCompacting: Bool = false
    var onRefresh: (() async -> Void)?
    var onInteraction: (() -> Void)?
    var onDeleteQueued: ((UUID) -> Void)?
    var conversation: Conversation?
    var conversationStore: ConversationStore?
    var connection: ConnectionManager?
    var window: ChatWindow?
    var windowManager: WindowManager?
    var onSelectConversation: ((Conversation) -> Void)?
    var onSeeAllConversations: (() -> Void)?
    var onNewConversation: (() -> Void)?
    var environmentStore: EnvironmentStore?
    var conversationOutput: ConversationOutput?

    @State private var isInitialLoad = true
    @State private var scrollViewportHeight: CGFloat = 0
    @State private var refreshingMessageId: UUID?
    @State private var scrollPos = ScrollPosition()

    private var streamingId: String {
        "streaming-\(conversationId?.uuidString ?? "none")"
    }

    private var showLoadingIndicator: Bool {
        isInitialLoad && messages.isEmpty && conversationId != nil && currentOutput.isEmpty
    }

    private var showEmptyState: Bool {
        !isInitialLoad && messages.isEmpty && queuedMessages.isEmpty && currentOutput.isEmpty && conversationId != nil
    }

    private var hasRequiredDependencies: Bool {
        window != nil && conversationStore != nil && windowManager != nil && connection != nil
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if showLoadingIndicator {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if showEmptyState {
                EmptyConversationView(
                    connection: connection,
                    conversationStore: conversationStore,
                    environmentStore: environmentStore,
                    conversation: conversation,
                    windowManager: windowManager,
                    window: window,
                    onSelectConversation: onSelectConversation,
                    onSeeAll: onSeeAllConversations
                )
            }

            if !showEmptyState || !hasRequiredDependencies {
                scrollableContent
            }
        }
        .background(Color.themeBackground)
        .onChange(of: conversationId) { _, _ in
            isInitialLoad = messages.isEmpty
        }
    }

    private var scrollableContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    messageListSection(viewportHeight: scrollViewportHeight)
                    if agentState == .running && currentOutput.isEmpty && currentToolCalls.isEmpty && currentRunStats == nil && !isCompacting {
                        sisyphusSection
                    }
                    if !currentToolCalls.isEmpty || !currentOutput.isEmpty || currentRunStats != nil || isCompacting {
                        streamingSection
                    }
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
        .onChange(of: currentOutput) { oldValue, newValue in
            if !newValue.isEmpty && isInitialLoad {
                isInitialLoad = false
            }
        }
        .onChange(of: messages.count) { old, new in
            if new > 0 && isInitialLoad {
                isInitialLoad = false
            }
            if new > old, messages.last?.isUser == true {
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
            try? await Task.sleep(nanoseconds: 300_000_000)
            if isInitialLoad {
                isInitialLoad = false
            }
        }
    }

private func messageListSection(viewportHeight: CGFloat) -> some View {
        ForEach(messages) { message in
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

    private func toggleCollapse(_ message: ChatMessage) {
        if let conversation, let store = conversationStore {
            store.updateMessage(message.id, in: conversation) { $0.isCollapsed.toggle() }
        }
    }

    private func refreshMessage(_ message: ChatMessage) {
        guard let conversation, let sessionId = conversation.sessionId,
              let workingDir = conversation.workingDirectory, !workingDir.isEmpty else { return }
        refreshingMessageId = message.id
        connection?.syncHistory(sessionId: sessionId, workingDirectory: workingDir, environmentId: conversation.environmentId)
    }

    private var sisyphusSection: some View {
        HStack {
            SisyphusLoadingView()
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .transition(.opacity)
    }

    @ViewBuilder
    private var streamingSection: some View {
        if let output = conversationOutput {
            StreamingContentObserver(output: output, isCompacting: isCompacting)
                .id(streamingId)
        }
    }

    private var queuedMessagesSection: some View {
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

struct StreamingContentObserver: View {
    @ObservedObject var output: ConversationOutput
    var isCompacting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isCompacting {
                CompactingIndicator()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            if !output.text.isEmpty || !output.toolCalls.isEmpty || output.runStats != nil {
                StreamingInterleavedOutput(
                    text: output.text,
                    toolCalls: output.toolCalls,
                    runStats: output.runStats
                )
            }
        }
    }
}

struct CompactingIndicator: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .rotationEffect(.degrees(pulse ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: pulse)
            Text("Compacting")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(.cyan)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.cyan.opacity(0.12))
        .cornerRadius(10)
        .onAppear { pulse = true }
    }
}
