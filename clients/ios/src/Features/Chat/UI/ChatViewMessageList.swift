import SwiftData
import SwiftUI

struct ChatViewMessageList: View {
    let session: Session
    @Binding var folderPickerRequest: SessionFolderPickerRequest?
    @Query private var messages: [ChatMessage]
    @State private var lastAnchoredUserId: UUID?
    @State private var groupCache = GroupCache()

    init(
        session: Session,
        folderPickerRequest: Binding<SessionFolderPickerRequest?>
    ) {
        self.session = session
        _folderPickerRequest = folderPickerRequest
        let sessionId = session.id
        _messages = Query(
            filter: #Predicate<ChatMessage> { $0.sessionId == sessionId },
            sort: [SortDescriptor(\.createdAt)]
        )
    }

    var body: some View {
        let _ = PerfCounters.bump("ml.body")
        let sections = groupCache.sections(for: messages)
        ZStack {
            messageList(sections: sections)
                .opacity(messages.isEmpty ? 0 : 1)
                .allowsHitTesting(!messages.isEmpty)
            if messages.isEmpty {
                SessionEmptyView(session: session, folderPickerRequest: $folderPickerRequest)
            }
        }
    }

    private func messageList(sections: MessageListSections) -> some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
                        ForEach(sections.groups, id: \.groupId) { group in
                            ChatViewMessageListGroup(
                                session: session,
                                messages: group.messages,
                                isStreamingLastGroup: group.groupId == sections.lastGroupId
                                    && session.isStreaming
                            )
                            .transition(.opacity)
                        }
                        ForEach(sections.queued, id: \.id) { message in
                            ChatViewMessageListQueuedRow(message: message)
                                .id(message.id)
                                .transition(.opacity)
                        }
                        Color.clear.frame(height: spacerHeight(in: geo))
                        Color.clear.frame(height: 0).id("bottom")
                    }
                    .padding(.vertical, ThemeTokens.Spacing.m)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: messages.count)
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.85), value: lastAnchoredUserId)
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(for: CGFloat.self) {
                    $0.contentOffset.y
                } action: {
                    old, new in
                    if abs(new - old) > 1 {
                        PerfCounters.event(
                            "scroll offsetY \(String(format: "%.1f", old)) -> \(String(format: "%.1f", new))"
                        )
                    }
                }
                .onAppear {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .onChange(of: sections.lastUserMessageId) { _, id in
                    if let id, id != lastAnchoredUserId {
                        lastAnchoredUserId = id
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func spacerHeight(in geo: GeometryProxy) -> CGFloat {
        lastAnchoredUserId != nil ? geo.size.height * 0.7 : 0
    }
}

private struct MessageGroup {
    let groupId: UUID
    let messages: [ChatMessage]
}

private struct MessageListSections {
    let groups: [MessageGroup]
    let queued: [ChatMessage]
    let lastGroupId: UUID?
    let lastUserMessageId: UUID?
}

private struct MessageCacheKey: Equatable {
    let id: UUID
    let stateRaw: String
    let roleRaw: String
}

private final class GroupCache {
    private var key: [MessageCacheKey] = []
    private var cached = MessageListSections(
        groups: [], queued: [], lastGroupId: nil, lastUserMessageId: nil)

    func sections(for messages: [ChatMessage]) -> MessageListSections {
        let newKey = messages.map {
            MessageCacheKey(id: $0.id, stateRaw: $0.stateRaw, roleRaw: $0.roleRaw)
        }
        if newKey == key { return cached }
        PerfCounters.bump("ml.grouped")
        var groups: [[ChatMessage]] = []
        var queued: [ChatMessage] = []
        var lastUserMessageId: UUID?
        for message in messages {
            if message.role == .user { lastUserMessageId = message.id }
            if message.state == .queued {
                queued.append(message)
            } else {
                if var last = groups.last, last.first?.role == message.role {
                    last.append(message)
                    groups[groups.count - 1] = last
                } else {
                    groups.append([message])
                }
            }
        }
        let messageGroups = groups.map { MessageGroup(groupId: $0.first?.id ?? UUID(), messages: $0) }
        cached = MessageListSections(
            groups: messageGroups,
            queued: queued,
            lastGroupId: messageGroups.last?.groupId,
            lastUserMessageId: lastUserMessageId
        )
        key = newKey
        return cached
    }
}
