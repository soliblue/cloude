import SwiftUI
import CloudeShared

struct ConversationInfoLabel: View {
    let conversation: Conversation?
    var showCost: Bool = false
    var placeholderText: String = "Select conversation..."

    var body: some View {
        HStack(spacing: 5) {
            Image.safeSymbol(conversation?.symbol)
                .font(.system(size: 15))
            if let conv = conversation {
                Text(conv.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            } else {
                Text(placeholderText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let folder = conversation?.workingDirectory?.nilIfEmpty?.lastPathComponent {
                Text("• \(folder)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if showCost, let conv = conversation, conv.totalCost > 0 {
                Text("• $\(String(format: "%.2f", conv.totalCost))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
    }
}

struct WindowHeaderView: View {
    let conversation: Conversation?
    let onSelectConversation: (() -> Void)?

    var body: some View {
        Button(action: { onSelectConversation?() }) {
            HStack(spacing: 6) {
                ConversationInfoLabel(conversation: conversation)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.oceanSecondary)
        }
        .buttonStyle(.plain)
    }
}

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
    var onNewConversation: (() -> Void)?

    @State private var lastUserMessageCount = 0
    @State private var isInitialLoad = true
    @State private var isBottomVisible = true
    @State private var isCostBannerDismissed = false
    @State private var scrollViewportHeight: CGFloat = 0

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
        !isInitialLoad && messages.isEmpty && currentOutput.isEmpty && conversationId != nil
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
                EmptyConversationView()
            }

            if !showEmptyState || !hasRequiredDependencies {
                ScrollViewReader { proxy in
                    scrollableContent(proxy: proxy, userMessageCount: userMessageCount)
                }

                scrollToBottomButton
            }
        }
        .background(Color.oceanBackground)
        .animation(.easeInOut(duration: 0.2), value: isBottomVisible)
        .onChange(of: conversationId) { _, _ in
            isInitialLoad = messages.isEmpty
            isCostBannerDismissed = false
        }
    }

    private func scrollableContent(proxy: ScrollViewProxy, userMessageCount: Int) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                costBannerSection
                messageListSection(viewportHeight: scrollViewportHeight)
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
        }
        .coordinateSpace(name: "chatScroll")
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
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
        .simultaneousGesture(
            DragGesture(minimumDistance: 5)
                .onChanged { _ in
                    onInteraction?()
                }
                .onEnded { _ in }
        )
        .onAppear {
            scrollProxy = proxy
            lastUserMessageCount = userMessageCount
            if !messages.isEmpty {
                isInitialLoad = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    proxy.scrollTo(bottomId, anchor: .bottom)
                }
            }
        }
        .onChange(of: userMessageCount) { oldCount, newCount in
            if newCount == oldCount + 1 {
                if let lastUserMessage = messages.last(where: { $0.isUser }) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        scrollToMessage(lastUserMessage.id, anchor: .top)
                    }
                }
            }
            lastUserMessageCount = newCount
        }
        .onChange(of: currentOutput) { oldValue, newValue in
            if !newValue.isEmpty && isInitialLoad {
                isInitialLoad = false
            }
            if isBottomVisible && !newValue.isEmpty {
                proxy.scrollTo(bottomId, anchor: .bottom)
            }
        }
        .onChange(of: messages.count) { _, newCount in
            if newCount > 0 && isInitialLoad {
                isInitialLoad = false
            }
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

    @ViewBuilder
    private var costBannerSection: some View {
        if let conv = conversation,
           let limit = conv.costLimitUsd,
           limit > 0,
           conv.totalCost >= limit * 0.75 {
            let isExceeded = conv.totalCost >= limit
            if isExceeded || !isCostBannerDismissed {
                CostBanner(
                    currentCost: conv.totalCost,
                    limit: limit,
                    onDismiss: { isCostBannerDismissed = true },
                    onNewChat: { onNewConversation?() }
                )
            }
        }
    }

    private func messageListSection(viewportHeight: CGFloat) -> some View {
        ForEach(messages) { message in
            MessageBubble(
                message: message,
                skills: connection?.skills ?? [],
                onRefresh: message.isUser ? nil : { refreshMessage(message) },
                onToggleCollapse: message.isUser ? nil : { toggleCollapse(message) }
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
        if let store = conversationStore, let index = store.messages(for: conversation).lastIndex(where: { $0.id == message.id }) {
            store.truncateMessages(for: conversation, from: index)
        }
        connection?.syncHistory(sessionId: sessionId, workingDirectory: workingDir)
    }

    private var streamingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isCompacting {
                CompactingIndicator()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            if !currentOutput.isEmpty || !currentToolCalls.isEmpty || currentRunStats != nil {
                StreamingInterleavedOutput(
                    text: currentOutput,
                    toolCalls: currentToolCalls,
                    runStats: currentRunStats
                )
            }
        }
        .id(streamingId)
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
                            conversationSymbol: conv.symbol
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
            SwipeToDeleteBubble(message: message, skills: connection?.skills ?? []) {
                onDeleteQueued?(message.id)
            }
            .id("\(message.id)-queued")
        }
    }

    @ViewBuilder
    private var scrollToBottomButton: some View {
        if !isBottomVisible && !messages.isEmpty {
            Circle()
                .fill(Color.oceanSecondary)
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
                            withAnimation(.easeOut(duration: 0.2)) {
                                scrollProxy?.scrollTo(bottomId, anchor: .bottom)
                            }
                        }
                )
                .padding(.trailing, 16)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }

    private func scrollToMessage(_ id: UUID, anchor: UnitPoint = .top) {
        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy?.scrollTo(id, anchor: anchor)
        }
    }
}

struct SwipeToDeleteBubble: View {
    let message: ChatMessage
    var skills: [Skill] = []
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showDelete = false

    private let deleteThreshold: CGFloat = -60

    var body: some View {
        ZStack(alignment: .trailing) {
            if showDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60)
                        .frame(maxHeight: .infinity)
                        .background(Color.red)
                }
                .transition(.opacity)
            }

            MessageBubble(message: message, skills: skills)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let translation = value.translation.width
                            if translation < 0 {
                                offset = translation
                                showDelete = translation < deleteThreshold
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < deleteThreshold {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    offset = -400
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onDelete()
                                }
                            } else {
                                withAnimation(.spring(response: 0.3)) {
                                    offset = 0
                                    showDelete = false
                                }
                            }
                        }
            )
        }
        .clipped()
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
        .cornerRadius(14)
        .onAppear { pulse = true }
    }
}
