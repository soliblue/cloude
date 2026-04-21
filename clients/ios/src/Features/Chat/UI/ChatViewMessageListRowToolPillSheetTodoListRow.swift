import SwiftUI

struct ChatViewMessageListRowToolPillSheetTodoListRow: View {
    let item: ChatTodoItem

    var body: some View {
        HStack(spacing: ThemeTokens.Spacing.m) {
            Image(systemName: icon)
                .appFont(size: ThemeTokens.Text.m, weight: .medium)
                .foregroundColor(color)
            Text(item.content)
                .appFont(size: ThemeTokens.Text.m)
                .foregroundColor(item.status == .completed ? .secondary : .primary)
                .strikethrough(item.status == .completed, color: .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, ThemeTokens.Spacing.s)
        .padding(.horizontal, ThemeTokens.Spacing.m)
    }

    private var icon: String {
        switch item.status {
        case .completed: return "checkmark.circle.fill"
        case .inProgress: return "circle.dotted.circle"
        case .pending: return "circle"
        }
    }

    private var color: Color {
        switch item.status {
        case .completed: return ThemeColor.success
        case .inProgress: return ThemeColor.mint
        case .pending: return .secondary
        }
    }
}
