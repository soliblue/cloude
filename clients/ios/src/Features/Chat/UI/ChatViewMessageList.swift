import SwiftData
import SwiftUI

struct ChatViewMessageList: View {
    let session: Session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var folderPickerRequest: SessionFolderPickerRequest?
    @Query private var messages: [ChatMessage]
    @Query private var queuedMessages: [ChatMessage]
    @Query private var latestUserMessages: [ChatMessage]
    @Query private var taskCalls: [ChatToolCall]
    @State private var lastAnchoredUserId: UUID?
    @State private var groupCache = ChatMessageGroupStore()
    @State private var historyWindow = ChatHistoryWindow()
    @State private var pendingHistoryAnchor: UUID?
    @State private var isInitiallyFollowing = true

    init(
        session: Session,
        folderPickerRequest: Binding<SessionFolderPickerRequest?>
    ) {
        self.session = session
        _folderPickerRequest = folderPickerRequest
        let sessionId = session.id
        _messages = Query(
            filter: #Predicate<ChatMessage> { $0.sessionId == sessionId && $0.stateRaw != "queued" },
            sort: [SortDescriptor(\.createdAt)]
        )
        _queuedMessages = Query(
            filter: #Predicate<ChatMessage> { $0.sessionId == sessionId && $0.stateRaw == "queued" },
            sort: [SortDescriptor(\.createdAt)])
        var latestUser = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> { $0.sessionId == sessionId && $0.roleRaw == "user" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        latestUser.fetchLimit = 1
        _latestUserMessages = Query(latestUser)
        _taskCalls = Query(
            filter: #Predicate<ChatToolCall> {
                $0.sessionId == sessionId && $0.parentToolUseId == nil
                    && ($0.name == "TaskCreate" || $0.name == "TaskUpdate" || $0.name == "TodoWrite"
                        || $0.name == "update_plan")
            },
            sort: \ChatToolCall.order)
    }

    var body: some View {
        let _ = PerfCounters.bump("ml.body")
        if messages.isEmpty && queuedMessages.isEmpty {
            SessionEmptyView(session: session, folderPickerRequest: $folderPickerRequest)
        } else {
            messageList
        }
    }

    private var messageList: some View {
        let queued = queuedMessages
        let groups = groupCache.groups(for: messages)
        let groupIds = groups.map(\.groupId)
        let startIndex = historyWindow.startIndex(sessionId: session.id, groupIds: groupIds)
        let taskItems = ChatTaskList.items(from: taskCalls)
        let taskMessageIds = Set(taskCalls.map(\.messageId))
        return GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
                        if startIndex > 0 {
                            Button {
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    isInitiallyFollowing = false
                                    pendingHistoryAnchor = historyWindow.loadEarlier(
                                        sessionId: session.id, groupIds: groupIds)
                                }
                            } label: {
                                Label("Load earlier messages", systemImage: "arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .padding(.horizontal, ThemeTokens.Spacing.m)
                            .accessibilityHint(
                                "Shows the previous 50 message groups without changing this conversation")
                        }
                        ForEach(groups.dropFirst(startIndex), id: \.groupId) { group in
                            ChatViewMessageListGroup(
                                session: session,
                                messages: group.messages,
                                isLast: group.groupId == groups.last?.groupId,
                                taskItems: taskItems,
                                taskMessageIds: taskMessageIds
                            )
                            .id("group-\(group.groupId.uuidString)")
                            .transition(.opacity)
                        }
                        ForEach(queued, id: \.id) { message in
                            ChatViewMessageListQueuedRow(message: message, provider: session.provider)
                                .id(message.id)
                                .transition(.opacity)
                        }
                        Color.clear.frame(height: spacerHeight(in: geo))
                        Color.clear.frame(height: 0).id("bottom")
                    }
                    .padding(.vertical, ThemeTokens.Spacing.m)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85),
                        value: groups.count + queued.count
                    )
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: lastAnchoredUserId)
                }
                .scrollIndicators(.hidden)
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .defaultScrollAnchor(isInitiallyFollowing ? .bottom : nil, for: .sizeChanges)
                .onScrollPhaseChange { _, phase in
                    if phase != .idle {
                        isInitiallyFollowing = false
                    }
                }
                #if DEBUG
                .onScrollGeometryChange(for: [CGFloat].self) {
                    [
                        $0.contentOffset.y, $0.contentSize.height, $0.containerSize.height,
                        $0.visibleRect.minY, $0.visibleRect.maxY,
                        $0.contentInsets.top, $0.contentInsets.bottom,
                    ]
                } action: { old, new in
                    if PerfCounters.enabled && zip(old, new).contains(where: { abs($0 - $1) > 1 }) {
                        PerfCounters.event(
                            "scroll geometry offset/content/viewport/visibleMin/visibleMax/insetTop/insetBottom "
                                + new.map { String(format: "%.1f", $0) }.joined(separator: "/")
                        )
                    }
                }
                #endif
                .onChange(of: groups.count, initial: true) { _, _ in
                    historyWindow.synchronize(sessionId: session.id, groupIds: groupIds)
                }
                .onChange(of: pendingHistoryAnchor) { _, anchor in
                    if let anchor {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            proxy.scrollTo("group-\(anchor.uuidString)", anchor: .top)
                            pendingHistoryAnchor = nil
                        }
                    }
                }
                .onChange(of: lastUserMessageId) { _, id in
                    if let id, id != lastAnchoredUserId {
                        isInitiallyFollowing = false
                        lastAnchoredUserId = id
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
            }
        }
        .id(session.id)
        .onChange(of: session.id) { _, _ in
            pendingHistoryAnchor = nil
            isInitiallyFollowing = true
            lastAnchoredUserId = nil
            historyWindow.synchronize(sessionId: session.id, groupIds: groupIds)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func spacerHeight(in geo: GeometryProxy) -> CGFloat {
        lastAnchoredUserId != nil ? geo.size.height * 0.7 : 0
    }

    private var lastUserMessageId: UUID? {
        latestUserMessages.first?.id
    }
}
