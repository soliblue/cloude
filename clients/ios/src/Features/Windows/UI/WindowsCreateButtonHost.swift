import SwiftData
import SwiftUI

struct WindowsCreateButtonHost: View {
    let session: Session
    let action: () -> Void
    @Query private var messages: [ChatMessage]

    init(session: Session, action: @escaping () -> Void) {
        self.session = session
        self.action = action
        let sessionId = session.id
        _messages = Query(filter: #Predicate<ChatMessage> { $0.sessionId == sessionId })
    }

    var body: some View {
        if !messages.isEmpty {
            WindowsCreateButton(action: action)
        }
    }
}
