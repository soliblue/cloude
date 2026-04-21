import SwiftData
import SwiftUI

struct ChatViewMessageList: View {
    @Query private var messages: [ChatMessage]
    @State private var lastAnchoredUserId: UUID?

    init(sessionId: UUID) {
        _messages = Query(
            filter: #Predicate<ChatMessage> { $0.sessionId == sessionId },
            sort: [SortDescriptor(\.createdAt)]
        )
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            ChatViewMessageListRow(message: message)
                                .id(message.id)
                                .padding(
                                    .top,
                                    index == 0 || messages[index - 1].role != message.role
                                        ? ThemeTokens.Spacing.m : 0)
                        }
                        Color.clear.frame(height: lastAnchoredUserId != nil ? geo.size.height : 0)
                    }
                    .padding(ThemeTokens.Spacing.m)
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(.keyboard, edges: .bottom)
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

}
