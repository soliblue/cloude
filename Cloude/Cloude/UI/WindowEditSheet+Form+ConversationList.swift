import SwiftUI
import CloudeShared

extension WindowEditForm {
    @ViewBuilder
    func conversationListSection() -> some View {
        if !allConversations.isEmpty {
            let visible = Array(allConversations.prefix(visibleCount))
            LazyVStack(spacing: 0) {
                ForEach(visible) { conv in
                    Button(action: { onSelectConversation(conv) }) {
                        HStack(spacing: 10) {
                            Image.safeSymbol(conv.symbol)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conv.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    if let dir = conv.workingDirectory, !dir.isEmpty {
                                        Text(dir.lastPathComponent)
                                            .foregroundColor(.accentColor)
                                    }
                                    Text("\(conv.messages.count) msgs")
                                        .foregroundColor(.secondary)
                                }
                                .font(.caption2)
                            }
                            Spacer()
                            if let envId = conv.environmentId,
                               let env = environmentStore.environments.first(where: { $0.id == envId }) {
                                Image.safeSymbol(env.symbol)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            Text(relativeTime(conv.lastMessageAt))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if conv.id != visible.last?.id {
                        Divider()
                            .padding(.leading, 46)
                    }
                }

                if allConversations.count > visibleCount {
                    Button {
                        visibleCount += 20
                    } label: {
                        Text("\(allConversations.count - visibleCount) more")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
            .background(Color.themeSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    func relativeTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
