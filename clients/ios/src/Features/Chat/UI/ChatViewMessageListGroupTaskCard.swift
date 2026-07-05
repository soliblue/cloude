import SwiftData
import SwiftUI

struct ChatViewMessageListGroupTaskCard: View {
    let messageIds: [UUID]
    @Query private var calls: [ChatToolCall]
    @State private var expanded = true
    @Environment(\.theme) private var theme

    init(session: Session, messageIds: [UUID]) {
        self.messageIds = messageIds
        let sessionId = session.id
        _calls = Query(
            filter: #Predicate<ChatToolCall> {
                $0.sessionId == sessionId && $0.parentToolUseId == nil
                    && ($0.name == "TaskCreate" || $0.name == "TaskUpdate")
            },
            sort: \ChatToolCall.order)
    }

    var body: some View {
        let items = ChatTaskList.items(from: calls)
        if !items.isEmpty, calls.contains(where: { messageIds.contains($0.messageId) }) {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                header(items)
                if expanded {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            ChatViewMessageListRowToolPillSheetTodoListRow(item: item)
                            if index < items.count - 1 {
                                Divider().padding(.leading, ThemeTokens.Spacing.l)
                            }
                        }
                    }
                }
            }
            .padding(ThemeTokens.Spacing.m)
            .background(theme.palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
        }
    }

    private func header(_ items: [ChatTodoItem]) -> some View {
        Button { expanded.toggle() } label: {
            HStack(spacing: ThemeTokens.Spacing.s) {
                Image(systemName: "chevron.right")
                    .appFont(size: ThemeTokens.Text.s)
                    .foregroundColor(ThemeColor.secondary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                Text("\(items.count) task\(items.count == 1 ? "" : "s")")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium)
                Spacer()
                Text("\(items.filter { $0.status == .completed }.count)/\(items.count)")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                    .foregroundColor(ThemeColor.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
