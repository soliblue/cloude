import SwiftUI

struct ChatViewMessageListGroupTaskCard: View {
    let messageIds: [UUID]
    let taskItems: [ChatTodoItem]
    let taskMessageIds: Set<UUID>
    @State private var expanded = true
    @Environment(\.theme) private var theme

    var body: some View {
        if !taskItems.isEmpty, messageIds.contains(where: taskMessageIds.contains) {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                header(taskItems)
                if expanded {
                    VStack(spacing: 0) {
                        ForEach(Array(taskItems.enumerated()), id: \.offset) { index, item in
                            ChatViewMessageListRowToolPillSheetTodoListRow(item: item)
                            if index < taskItems.count - 1 {
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
        Button {
            expanded.toggle()
        } label: {
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
