import SwiftData
import SwiftUI

struct WindowsCreateButtonGate: View {
    let selectedPane: WindowsPane
    let isKeyboardVisible: Bool
    let focusedSession: Session?
    let action: () -> Void

    var body: some View {
        if selectedPane == .session, !isKeyboardVisible, let session = focusedSession {
            WindowsCreateButtonGateQuery(sessionId: session.id) {
                WindowsCreateButton(action: action)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .zIndex(1)
            }
        }
    }
}

private struct WindowsCreateButtonGateQuery<Content: View>: View {
    @Query private var messages: [ChatMessage]
    let content: () -> Content

    init(sessionId: UUID, @ViewBuilder content: @escaping () -> Content) {
        var descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> { $0.sessionId == sessionId }
        )
        descriptor.fetchLimit = 1
        _messages = Query(descriptor)
        self.content = content
    }

    var body: some View {
        if !messages.isEmpty {
            content()
        }
    }
}
