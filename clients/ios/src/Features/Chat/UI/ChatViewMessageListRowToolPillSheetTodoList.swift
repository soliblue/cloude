import SwiftUI

struct ChatViewMessageListRowToolPillSheetTodoList: View {
    let items: [ChatTodoItem]
    @Environment(\.theme) private var theme

    var body: some View {
        let completed = items.filter { $0.status == .completed }.count
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            Label("\(completed)/\(items.count) tasks", systemImage: "checklist")
                .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                .foregroundColor(.secondary)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    ChatViewMessageListRowToolPillSheetTodoListRow(item: item)
                    if index < items.count - 1 {
                        Divider().padding(.leading, ThemeTokens.Spacing.l)
                    }
                }
            }
            .background(theme.palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
        }
    }
}
