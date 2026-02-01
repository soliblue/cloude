import SwiftUI
import UIKit
import CloudeShared

struct WindowHeaderView: View {
    let project: Project?
    let conversation: Conversation?
    let onSelectConversation: (() -> Void)?

    var body: some View {
        Button(action: { onSelectConversation?() }) {
            HStack(spacing: 6) {
                if let conv = conversation {
                    if conv.symbol.isValidSFSymbol {
                        Image.safeSymbol(conv.symbol)
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
                            .lineLimit(1)
                            .truncationMode(.middle)
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
            .background(Color.oceanSecondary)
        }
        .buttonStyle(.plain)
    }
}

struct ProjectChatMessageList: View {
    let messages: [ChatMessage]
    var queuedMessages: [ChatMessage] = []
    let currentOutput: String
    let currentToolCalls: [ToolCall]
    let currentRunStats: (durationMs: Int, costUsd: Double)?
    @Binding var scrollProxy: ScrollViewProxy?
    let agentState: AgentState
    let conversationId: UUID?
    var isCompacting: Bool = false
    var onRefresh: (() async -> Void)?
    var onInteraction: (() -> Void)?
    var onDeleteQueued: ((UUID) -> Void)?
    var project: Project?
    var conversation: Conversation?
    var projectStore: ProjectStore?
    var connection: ConnectionManager?
    var window: ChatWindow?
    var windowManager: WindowManager?
    var onSelectConversation: ((Conversation) -> Void)?
    var onShowAllConversations: (() -> Void)?
    var onNewConversation: (() -> Void)?

    @State private var hasScrolledToStreaming = false
    @State private var lastUserMessageCount = 0
    @State private var showScrollToBottom = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isInitialLoad = true

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
        window != nil && projectStore != nil && windowManager != nil && connection != nil
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
            } else if showEmptyState && hasRequiredDependencies {
                ScrollView {
                    WindowEditForm(
                        window: window!,
                        projectStore: projectStore!,
                        windowManager: windowManager!,
                        connection: connection!,
                        onSelectConversation: { conv in onSelectConversation?(conv) },
                        onShowAllConversations: { onShowAllConversations?() },
                        onNewConversation: { onNewConversation?() },
                        showRemoveButton: false
                    )
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !showEmptyState || !hasRequiredDependencies {
                ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id("\(message.id)-\(message.isQueued)")
                        }

                        if !currentToolCalls.isEmpty || !currentOutput.isEmpty || currentRunStats != nil || isCompacting {
                            streamingView
                        }

                        ForEach(queuedMessages) { message in
                            SwipeToDeleteBubble(message: message) {
                                onDeleteQueued?(message.id)
                            }
                            .id("\(message.id)-queued")
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomId)

                        GeometryReader { geo in
                            let frame = geo.frame(in: .named("scrollArea"))
                            Color.clear
                                .preference(key: ScrollOffsetKey.self, value: frame.minY)
                        }
                        .frame(height: 1)
                    }
                }
                .scrollContentBackground(.hidden)
                .coordinateSpace(name: "scrollArea")
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    scrollOffset = offset
                    showScrollToBottom = offset < -200
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
                .onChange(of: currentOutput) { oldValue, newValue in
                    if newValue.isEmpty {
                        hasScrolledToStreaming = false
                    }
                    if !newValue.isEmpty && isInitialLoad {
                        isInitialLoad = false
                    }
                }
                .onChange(of: messages.count) { _, newCount in
                    if newCount > 0 && isInitialLoad {
                        isInitialLoad = false
                    }
                }
                .task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if isInitialLoad {
                        isInitialLoad = false
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
        }
        .animation(.easeInOut(duration: 0.2), value: showScrollToBottom)
        .onChange(of: conversationId) { _, _ in
            isInitialLoad = true
        }
    }

    private var streamingView: some View {
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

    private func scrollToMessage(_ id: UUID, anchor: UnitPoint = .top) {
        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy?.scrollTo(id, anchor: anchor)
        }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SwipeToDeleteBubble: View {
    let message: ChatMessage
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

            MessageBubble(message: message)
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
