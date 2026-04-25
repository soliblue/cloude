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
        if messages.isEmpty {
            SessionEmptyView(session: session, folderPickerRequest: $folderPickerRequest)
        } else {
            messageList
        }
    }

    private var messageList: some View {
        let groups = groupCache.groups(for: messages)
        return GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
                        ForEach(groups, id: \.groupId) { group in
                            ChatViewMessageListGroup(session: session, messages: group.messages)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
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
                .onChange(of: lastUserMessageId) { _, id in
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

    private var lastUserMessageId: UUID? {
        messages.last(where: { $0.role == .user })?.id
    }
}

private struct MessageGroup {
    let groupId: UUID
    let messages: [ChatMessage]
}

@Observable
private final class GroupCache {
    private var key: [UUID] = []
    private var cached: [MessageGroup] = []

    func groups(for messages: [ChatMessage]) -> [MessageGroup] {
        let newKey = messages.map(\.id)
        if newKey == key { return cached }
        PerfCounters.bump("ml.grouped")
        var groups: [[ChatMessage]] = []
        for message in messages {
            if var last = groups.last, last.first?.role == message.role {
                last.append(message)
                groups[groups.count - 1] = last
            } else {
                groups.append([message])
            }
        }
        cached = groups.map { MessageGroup(groupId: $0.first?.id ?? UUID(), messages: $0) }
        key = newKey
        return cached
    }
}
