import SwiftData
import SwiftUI

struct ChatViewMessageListGroupTaskCard: View {
    @Query private var toolCalls: [ChatToolCall]
    @Environment(\.theme) private var theme

    init(messageIds: [UUID]) {
        _toolCalls = Query(
            filter: #Predicate<ChatToolCall> {
                messageIds.contains($0.messageId) && $0.name == "TodoWrite"
            },
            sort: [SortDescriptor(\.order), SortDescriptor(\.id)]
        )
    }

    var body: some View {
        if let items = toolCalls.last?.todoItems, !items.isEmpty {
            let completed = items.filter { $0.status == .completed }.count
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                Label("\(completed)/\(items.count) tasks", systemImage: "checklist")
                    .appFont(size: ThemeTokens.Text.s, weight: .semibold)
                    .foregroundColor(.secondary)
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        ChatTaskRow(item: item)
                        if index < items.count - 1 {
                            Divider().padding(.leading, ThemeTokens.Spacing.l)
                        }
                    }
                }
            }
            .padding(ThemeTokens.Spacing.m)
            .background(theme.palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
        }
    }
}
