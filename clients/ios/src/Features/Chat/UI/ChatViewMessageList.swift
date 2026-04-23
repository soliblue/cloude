import SwiftData
import SwiftUI

struct ChatViewMessageList: View {
    let session: Session
    let bottomInset: CGFloat
    @Query private var messages: [ChatMessage]
    @State private var lastAnchoredUserId: UUID?

    init(session: Session, bottomInset: CGFloat = 0) {
        self.session = session
        self.bottomInset = bottomInset
        let sessionId = session.id
        _messages = Query(
            filter: #Predicate<ChatMessage> { $0.sessionId == sessionId },
            sort: [SortDescriptor(\.createdAt)]
        )
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
                        ForEach(groupedMessages, id: \.groupId) { group in
                            ChatViewMessageListGroup(session: session, messages: group.messages)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        Color.clear.frame(height: spacerHeight(in: geo))
                        Color.clear.frame(height: 0).id("bottom")
                    }
                    .padding(.vertical, ThemeTokens.Spacing.m)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: messages.count)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: lastAnchoredUserId)
                }
                .scrollIndicators(.hidden)
                .contentMargins(.bottom, bottomInset + ThemeTokens.Spacing.m, for: .scrollContent)
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

    private var groupedMessages: [MessageGroup] {
        var groups: [[ChatMessage]] = []
        for message in messages {
            if var last = groups.last, last.first?.role == message.role {
                last.append(message)
                groups[groups.count - 1] = last
            } else {
                groups.append([message])
            }
        }
        return groups.map { MessageGroup(groupId: $0.first?.id ?? UUID(), messages: $0) }
    }
}

private struct MessageGroup {
    let groupId: UUID
    let messages: [ChatMessage]
}
