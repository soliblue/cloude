import SwiftUI
import Combine
import CloudeShared

struct ChatMessageList: View {
    let messages: [ChatMessage]
    var queuedMessages: [ChatMessage] = []
    let currentOutput: String
    let currentToolCalls: [ToolCall]
    let currentRunStats: (durationMs: Int, costUsd: Double, model: String?)?
    @Binding var scrollProxy: ScrollViewProxy?
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
    @State private var isBottomVisible = true
@State private var scrollViewportHeight: CGFloat = 0
    @State private var userHasScrolled = false
    @State private var refreshingMessageId: UUID?

    private var bottomId: String {
        "bottom-\(conversationId?.uuidString ?? "none")"
    }

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
        let userMessageCount = messages.filter { $0.isUser }.count

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
                ScrollViewReader { proxy in
                    scrollableContent(proxy: proxy, userMessageCount: userMessageCount)
                }

                scrollToBottomButton
            }
        }
        .background(Color.themeBackground)
        .animation(.easeInOut(duration: 0.2), value: isBottomVisible)
        .onChange(of: conversationId) { _, _ in
            isInitialLoad = messages.isEmpty
userHasScrolled = false
        }
    }

    private func scrollableContent(proxy: ScrollViewProxy, userMessageCount: Int) -> some View {
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
                questionSection
                queuedMessagesSection

                Color.clear
                    .frame(height: 80)
                    .id(bottomId)
                    .onAppear { isBottomVisible = true }
                    .onDisappear { isBottomVisible = false }
            }
                Spacer(minLength: 0)
            }
            .frame(minHeight: scrollViewportHeight)
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
        .simultaneousGesture(
            TapGesture()
                .onEnded { onInteraction?() }
        )
        .onScrollPhaseChange { _, newPhase in
            if newPhase == .interacting {
                userHasScrolled = true
            }
        }
        .onAppear {
            scrollProxy = proxy
            if !messages.isEmpty && isInitialLoad {
                isInitialLoad = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    proxy.scrollTo(bottomId)
                }
            }
        }
        .onChange(of: userMessageCount) { oldCount, newCount in
            if newCount == oldCount + 1 {
                userHasScrolled = false
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(bottomId)
                }
            }
        }
        .onChange(of: currentOutput) { oldValue, newValue in
            if !newValue.isEmpty && isInitialLoad {
                isInitialLoad = false
            }
        }
        .onChange(of: messages.count) { _, newCount in
            if newCount > 0 && isInitialLoad {
                isInitialLoad = false
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

    @ViewBuilder
    private var questionSection: some View {
        if let pending = conversationStore?.pendingQuestion,
           pending.conversationId == conversationId {
            QuestionView(
                questions: pending.questions,
                isStreaming: agentState == .running || agentState == .compacting,
                onSubmit: { answer in
                    conversationStore?.pendingQuestion = nil
                    conversationStore?.questionInputFocused = false
                    if let conv = conversation, let store = conversationStore {
                        let userMessage = ChatMessage(isUser: true, text: answer)
                        store.addMessage(userMessage, to: conv)
                        connection?.sendChat(
                            answer,
                            workingDirectory: conv.workingDirectory,
                            sessionId: conv.sessionId,
                            isNewSession: false,
                            conversationId: conv.id,
                            conversationName: conv.name,
                            conversationSymbol: conv.symbol,
                            environmentId: conv.environmentId
                        )
                    }
                },
                onDismiss: {
                    conversationStore?.questionInputFocused = false
                    if let conv = conversation, let store = conversationStore {
                        let skipMessage = ChatMessage(isUser: true, text: "(skipped question)")
                        store.addMessage(skipMessage, to: conv)
                    }
                    conversationStore?.pendingQuestion = nil
                },
                onFocusChange: { focused in
                    conversationStore?.questionInputFocused = focused
                    if focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                scrollProxy?.scrollTo("question-input", anchor: .bottom)
                            }
                        }
                    }
                }
            )
            .id("question-input")
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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

    @ViewBuilder
    private var scrollToBottomButton: some View {
        if !isBottomVisible && !messages.isEmpty {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.themeSecondary)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .overlay {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .highPriorityGesture(
                    TapGesture()
                        .onEnded {
                            userHasScrolled = false
                            withAnimation(.easeOut(duration: 0.2)) {
                                scrollProxy?.scrollTo(bottomId)
                            }
                        }
                )
                .padding(.trailing, 16)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
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
