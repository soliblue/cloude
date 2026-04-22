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
                        ForEach(Array(groupedMessages.enumerated()), id: \.offset) { _, group in
                            ChatViewMessageListGroup(session: session, messages: group)
                        }
                        Color.clear.frame(height: lastAnchoredUserId != nil ? geo.size.height : 0)
                        Color.clear.frame(height: 0).id("bottom")
                    }
                    .padding(.vertical, ThemeTokens.Spacing.m)
                }
                .scrollIndicators(.hidden)
                .contentMargins(.bottom, bottomInset + ThemeTokens.Spacing.m, for: .scrollContent)
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .onAppear {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .onChange(of: lastUserMessageId) { _, id in
                    if let id, id != lastAnchoredUserId {
                        lastAnchoredUserId = id
                        withAnimation { proxy.scrollTo(id, anchor: .top) }
                    }
                }
            }
        }
    }

    private var lastUserMessageId: UUID? {
        messages.last(where: { $0.role == .user })?.id
    }

    private var groupedMessages: [[ChatMessage]] {
        var groups: [[ChatMessage]] = []
        for message in messages {
            if var last = groups.last, last.first?.role == message.role {
                last.append(message)
                groups[groups.count - 1] = last
            } else {
                groups.append([message])
            }
        }
        return groups
    }
}
