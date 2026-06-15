import SwiftUI

struct ChatInputBarTaskList: View {
    let sessionId: UUID
    @State private var expanded = false
    @Environment(\.theme) private var theme

    var body: some View {
        let items = ChatLiveTasks.snapshot(for: sessionId).items
        if !items.isEmpty {
            let completed = items.filter { $0.status == .completed }.count
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                header(items: items, completed: completed)
                if expanded {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                ChatTaskRow(item: item)
                            }
                        }
                    }
                    .frame(maxHeight: ThemeTokens.Size.xl)
                }
                ProgressView(value: Double(completed), total: Double(items.count))
                    .tint(ThemeColor.mint)
            }
            .padding(.vertical, ThemeTokens.Spacing.s)
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .background(theme.palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
        }
    }

    private func header(items: [ChatTodoItem], completed: Int) -> some View {
        let current = items.first { $0.status == .inProgress }
        return Button {
            withAnimation(.easeOut(duration: ThemeTokens.Duration.s)) { expanded.toggle() }
        } label: {
            HStack(spacing: ThemeTokens.Spacing.s) {
                Image(systemName: "checklist")
                    .appFont(size: ThemeTokens.Text.s)
                    .foregroundColor(.secondary)
                Text(current?.content ?? "Tasks")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Spacer(minLength: ThemeTokens.Spacing.s)
                Text("\(completed)/\(items.count)")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.up")
                    .appFont(size: ThemeTokens.Text.s)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
                    .frame(width: ThemeTokens.Icon.s, height: ThemeTokens.Icon.s)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
