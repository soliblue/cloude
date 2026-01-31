import SwiftUI
import CloudeShared

struct WindowHeaderView: View {
    let project: Project?
    let conversation: Conversation?
    let onSelectConversation: (() -> Void)?

    var body: some View {
        Button(action: { onSelectConversation?() }) {
            HStack(spacing: 6) {
                if let conv = conversation {
                    if let symbol = conv.symbol {
                        Image(systemName: symbol)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    Text(conv.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if let proj = project {
                        Text("• \(proj.name)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Select conversation...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
        }
        .buttonStyle(.plain)
    }
}

struct ProjectChatMessageList: View {
    let messages: [ChatMessage]
    let currentOutput: String
    let currentToolCalls: [ToolCall]
    let currentRunStats: (durationMs: Int, costUsd: Double)?
    @Binding var scrollProxy: ScrollViewProxy?
    let agentState: AgentState
    let conversationId: UUID?
    var onRefresh: (() async -> Void)?
    var onInteraction: (() -> Void)?

    @State private var hasScrolledToStreaming = false
    @State private var lastUserMessageCount = 0
    @State private var showScrollToBottom = false
    @State private var bottomPullOffset: CGFloat = 0
    @State private var isRefreshingFromBottom = false

    private var bottomId: String {
        "bottom-\(conversationId?.uuidString ?? "none")"
    }

    private var streamingId: String {
        "streaming-\(conversationId?.uuidString ?? "none")"
    }

    var body: some View {
        let userMessageCount = messages.filter { $0.isUser }.count

        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            MessageBubble(message: message)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }

                        if !currentToolCalls.isEmpty || !currentOutput.isEmpty || currentRunStats != nil {
                            streamingView
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomId)
                            .onAppear { showScrollToBottom = false }
                            .onDisappear { showScrollToBottom = true }

                        GeometryReader { geo in
                            let offset = geo.frame(in: .named("scrollView")).maxY - geo.size.height
                            Color.clear
                                .preference(key: BottomOverscrollKey.self, value: offset)
                        }
                        .frame(height: 1)
                    }
                    .padding(.bottom, 16)
                }
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(BottomOverscrollKey.self) { offset in
                    bottomPullOffset = offset
                    if offset < -60 && !isRefreshingFromBottom {
                        isRefreshingFromBottom = true
                        Task {
                            await onRefresh?()
                            isRefreshingFromBottom = false
                        }
                    }
                }
                .refreshable {
                    await onRefresh?()
                }
                .scrollDismissesKeyboard(.immediately)
                .onTapGesture {
                    onInteraction?()
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { _ in onInteraction?() }
                )
                .onAppear {
                    scrollProxy = proxy
                    lastUserMessageCount = userMessageCount
                    if !messages.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            proxy.scrollTo(bottomId, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: userMessageCount) { oldCount, newCount in
                    if newCount > oldCount, let lastUserMessage = messages.last(where: { $0.isUser }) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            scrollToMessage(lastUserMessage.id, anchor: .top)
                        }
                    }
                    lastUserMessageCount = newCount
                }
                .animation(.easeOut(duration: 0.25), value: messages.count)
                .onChange(of: currentOutput) { oldValue, newValue in
                    if oldValue.isEmpty && !newValue.isEmpty && !hasScrolledToStreaming {
                        hasScrolledToStreaming = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                scrollProxy?.scrollTo(streamingId, anchor: .top)
                            }
                        }
                    }
                    if newValue.isEmpty {
                        hasScrolledToStreaming = false
                    }
                }
            }

            if showScrollToBottom {
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    .overlay {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 14, weight: .semibold))
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
        .animation(.easeInOut(duration: 0.2), value: showScrollToBottom)
    }

    private var streamingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !currentToolCalls.isEmpty {
                ToolCallsSection(toolCalls: currentToolCalls)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            if !currentOutput.isEmpty || !currentToolCalls.isEmpty {
                StreamingInterleavedOutput(text: currentOutput, toolCalls: currentToolCalls)
            }
            Group {
                if let stats = currentRunStats {
                    RunStatsView(durationMs: stats.durationMs, costUsd: stats.costUsd)
                        .transition(.opacity)
                } else {
                    Color.clear
                }
            }
            .frame(height: 20)
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .id(streamingId)
    }

    private func scrollToMessage(_ id: UUID, anchor: UnitPoint = .top) {
        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy?.scrollTo(id, anchor: anchor)
        }
    }
}

private struct BottomOverscrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
