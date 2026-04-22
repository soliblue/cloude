import SwiftData
import SwiftUI

struct WindowsSidebarOpenRowStatus: View {
    let session: Session
    let isFocused: Bool
    let canClose: Bool
    let onClose: () -> Void
    @Query private var messages: [ChatMessage]
    @Environment(\.appAccent) private var appAccent

    init(
        session: Session,
        isFocused: Bool,
        canClose: Bool,
        onClose: @escaping () -> Void
    ) {
        self.session = session
        self.isFocused = isFocused
        self.canClose = canClose
        self.onClose = onClose
        let sessionId = session.id
        _messages = Query(
            filter: #Predicate<ChatMessage> { $0.sessionId == sessionId },
            sort: \.createdAt,
            order: .reverse
        )
    }

    var body: some View {
        if session.isStreaming {
            dot(color: ThemeColor.yellow)
        } else if isUnread {
            dot(color: appAccent.color)
        } else if canClose {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    .foregroundColor(.secondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var isUnread: Bool {
        if isFocused { return false }
        for message in messages where message.role == .assistant && message.state == .complete {
            return message.createdAt > session.lastOpenedAt
        }
        return false
    }

    private func dot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: ThemeTokens.Size.s, height: ThemeTokens.Size.s)
    }
}
