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
    var onSelectConversation: ((Conversation) -> Void)?
    var onShowAllConversations: (() -> Void)?
    var onNewConversation: (() -> Void)?

    @State private var hasScrolledToStreaming = false
    @State private var lastUserMessageCount = 0
    @State private var showScrollToBottom = false
    @State private var bottomPullOffset: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var isRefreshingFromBottom = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isInitialLoad = true
    @State private var showFolderPicker = false
    @State private var showSymbolPicker = false
    @State private var editName = ""
    @State private var editSymbol = ""

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

    private var canChangeFolder: Bool {
        guard let conv = conversation else { return false }
        return conv.messages.isEmpty && conv.sessionId == nil
    }

    private var currentFolderPath: String {
        conversation?.workingDirectory ?? project?.rootDirectory ?? ""
    }

    private var folderDisplayName: String {
        let path = currentFolderPath
        if path.isEmpty { return "No folder selected" }
        return (path as NSString).lastPathComponent
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
            } else if showEmptyState && canChangeFolder {
                emptyStateView
            }

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
                                .preference(key: BottomOverscrollKey.self, value: frame.minY)
                                .preference(key: ScrollOffsetKey.self, value: frame.minY)
                        }
                        .frame(height: 1)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(
                    GeometryReader { scrollGeo in
                        Color.clear
                            .preference(key: ScrollViewHeightKey.self, value: scrollGeo.size.height)
                    }
                )
                .coordinateSpace(name: "scrollArea")
                .onPreferenceChange(BottomOverscrollKey.self) { offset in
                    bottomPullOffset = offset
                    checkBottomOverscroll()
                }
                .onPreferenceChange(ScrollViewHeightKey.self) { height in
                    scrollViewHeight = height
                }
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    scrollOffset = offset
                    showScrollToBottom = offset < -200
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

    private var recentConversations: [Conversation] {
        guard let proj = project else { return [] }
        return proj.conversations
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
            .filter { $0.id != conversation?.id }
            .prefix(5)
            .map { $0 }
    }

    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Button(action: { showSymbolPicker = true }) {
                        Image.safeSymbol(editSymbol.isEmpty ? nil : editSymbol, fallback: "circle.dashed")
                            .font(.system(size: 30))
                            .frame(width: 56, height: 56)
                            .background(Color.oceanSurface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    TextField("Name", text: $editName)
                        .font(.title3)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.oceanSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onChange(of: editName) { _, newValue in
                            if let proj = project, let conv = conversation, !newValue.isEmpty {
                                projectStore?.renameConversation(conv, in: proj, to: newValue)
                            }
                        }
                }

                if canChangeFolder {
                    Button(action: { showFolderPicker = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(folderDisplayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                if !currentFolderPath.isEmpty {
                                    Text(currentFolderPath)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.head)
                                }
                            }
                            Spacer()
                            Text("Change")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.oceanSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

                if !recentConversations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Recent")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: { onShowAllConversations?() }) {
                                Text("See All")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(recentConversations) { conv in
                                Button(action: { onSelectConversation?(conv) }) {
                                    HStack(spacing: 10) {
                                        Image.safeSymbol(conv.symbol)
                                            .font(.system(size: 17))
                                            .foregroundColor(.secondary)
                                            .frame(width: 24)
                                        Text(conv.name)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(relativeTime(conv.lastMessageAt))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)

                                if conv.id != recentConversations.last?.id {
                                    Divider()
                                        .padding(.leading, 46)
                                }
                            }
                        }
                        .background(Color.oceanSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                Button(action: { onNewConversation?() }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 18))
                        Text("New")
                    }
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.oceanSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showFolderPicker) {
            if let conn = connection {
                FolderPickerView(connection: conn) { path in
                    if let proj = project, let conv = conversation {
                        projectStore?.setWorkingDirectory(conv, in: proj, path: path)
                    }
                }
            }
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerSheet(selectedSymbol: $editSymbol)
        }
        .onChange(of: editSymbol) { _, newValue in
            if let proj = project, let conv = conversation {
                projectStore?.setConversationSymbol(conv, in: proj, symbol: newValue.isEmpty ? nil : newValue)
            }
        }
        .onAppear {
            editName = conversation?.name ?? ""
            editSymbol = conversation?.symbol ?? ""
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }

    private func scrollToMessage(_ id: UUID, anchor: UnitPoint = .top) {
        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy?.scrollTo(id, anchor: anchor)
        }
    }

    private func checkBottomOverscroll() {
        let overscroll = scrollViewHeight - bottomPullOffset
        if overscroll > 60 && !isRefreshingFromBottom && scrollViewHeight > 0 {
            isRefreshingFromBottom = true
            Task {
                await onRefresh?()
                isRefreshingFromBottom = false
            }
        }
    }
}

private struct BottomOverscrollKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollViewHeightKey: PreferenceKey {
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
