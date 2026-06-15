import SwiftData
import SwiftUI

struct SessionUnreadProbe: View {
    let session: Session
    @Query private var messages: [ChatMessage]

    init(session: Session) {
        self.session = session
        let sessionId = session.id
        var descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> {
                $0.sessionId == sessionId && $0.roleRaw == "assistant" && $0.stateRaw == "complete"
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        _messages = Query(descriptor)
    }

    var body: some View {
        Color.clear.preference(key: UnreadCountPreferenceKey.self, value: isUnread ? 1 : 0)
    }

    private var isUnread: Bool {
        messages.first.map { $0.createdAt > session.lastOpenedAt } ?? false
    }
}
