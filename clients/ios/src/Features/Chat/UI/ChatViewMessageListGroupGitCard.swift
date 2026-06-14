import SwiftData
import SwiftUI

struct ChatViewMessageListGroupGitCard: View {
    @Query private var changes: [ChatGitChange]
    @State private var expanded = false
    @State private var showAll = false
    @Environment(\.theme) private var theme

    private let collapsedLimit = 5

    init(messageId: UUID) {
        _changes = Query(
            filter: #Predicate<ChatGitChange> { $0.messageId == messageId },
            sort: \ChatGitChange.path)
    }

    var body: some View {
        if !changes.isEmpty {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                header
                if expanded {
                    ForEach(visible) { ChatViewMessageListGroupGitCardRow(change: $0) }
                    if !showAll && changes.count > collapsedLimit {
                        Button { showAll = true } label: {
                            Text("View \(changes.count - collapsedLimit) more files")
                                .appFont(size: ThemeTokens.Text.s)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(ThemeTokens.Spacing.m)
            .background(theme.palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
        }
    }

    private var visible: [ChatGitChange] {
        showAll ? changes : Array(changes.prefix(collapsedLimit))
    }

    private var header: some View {
        Button { expanded.toggle() } label: {
            HStack(spacing: ThemeTokens.Spacing.s) {
                Image(systemName: "chevron.right")
                    .appFont(size: ThemeTokens.Text.s)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                Text("\(changes.count) file\(changes.count == 1 ? "" : "s") changed")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium)
                Spacer()
                if totalAdd > 0 {
                    Text("+\(totalAdd)")
                        .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                        .foregroundColor(ThemeColor.success)
                }
                if totalDel > 0 {
                    Text("-\(totalDel)")
                        .appFont(size: ThemeTokens.Text.s, weight: .medium, design: .monospaced)
                        .foregroundColor(ThemeColor.danger)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var totalAdd: Int { changes.map(\.additions).reduce(0, +) }
    private var totalDel: Int { changes.map(\.deletions).reduce(0, +) }
}
