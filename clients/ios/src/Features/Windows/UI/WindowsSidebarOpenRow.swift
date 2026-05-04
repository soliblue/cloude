import SwiftData
import SwiftUI

struct WindowsSidebarOpenRow: View {
    let session: Session
    let isFocused: Bool
    let canClose: Bool
    let onActivate: () -> Void
    let onClose: () -> Void
    @Query private var messages: [ChatMessage]
    @Environment(\.appAccent) private var appAccent

    init(
        session: Session,
        isFocused: Bool,
        canClose: Bool,
        onActivate: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.session = session
        self.isFocused = isFocused
        self.canClose = canClose
        self.onActivate = onActivate
        self.onClose = onClose
        let sessionId = session.id
        _messages = Query(
            filter: #Predicate<ChatMessage> { $0.sessionId == sessionId },
            sort: \.createdAt,
            order: .reverse
        )
    }

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            WindowsSidebarRow(
                symbol: session.symbol,
                title: session.title,
                isFocused: isFocused,
                isStreaming: session.isStreaming,
                isUnread: isUnread
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onActivate)
            Spacer(minLength: 0)
            if canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .foregroundColor(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.l)
        .padding(.vertical, ThemeTokens.Spacing.s)
        .background(isFocused ? appAccent.color.opacity(0.15) : Color.clear)
        .padding(.horizontal, -ThemeTokens.Spacing.l)
    }

    private var isUnread: Bool {
        if isFocused { return false }
        for message in messages where message.role == .assistant && message.state == .complete {
            return message.createdAt > session.lastOpenedAt
        }
        return false
    }
}
