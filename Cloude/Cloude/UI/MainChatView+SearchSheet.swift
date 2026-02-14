import SwiftUI
import CloudeShared

struct ConversationSearchSheet: View {
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    let onSelect: (Conversation) -> Void

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var results: [Conversation] {
        let all = conversationStore.listableConversations
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
        if searchText.isEmpty { return all }
        let query = searchText.lowercased()
        return all.filter { conv in
            conv.name.lowercased().contains(query) ||
            (conv.workingDirectory?.lowercased().contains(query) ?? false) ||
            conv.messages.contains { $0.text.lowercased().contains(query) }
        }
    }

    private var grouped: [(directory: String, conversations: [Conversation])] {
        let dict = Dictionary(grouping: results) { $0.workingDirectory ?? "" }
        return dict.map { dir, convs in
            (directory: dir, conversations: convs.sorted { $0.lastMessageAt > $1.lastMessageAt })
        }.sorted { lhs, rhs in
            let lhsDate = lhs.conversations.first?.lastMessageAt ?? .distantPast
            let rhsDate = rhs.conversations.first?.lastMessageAt ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if results.isEmpty {
                        Text("No conversations found")
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    }

                    ForEach(grouped, id: \.directory) { group in
                        VStack(alignment: .leading, spacing: 0) {
                            if !group.directory.isEmpty {
                                Text(group.directory.lastPathComponent)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 6)
                            }

                            VStack(spacing: 0) {
                                ForEach(group.conversations) { conv in
                                    Button { onSelect(conv) } label: {
                                        conversationRow(conv)
                                    }
                                    .buttonStyle(.plain)

                                    if conv.id != group.conversations.last?.id {
                                        Divider()
                                            .padding(.leading, 46)
                                    }
                                }
                            }
                            .background(Color.oceanSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.oceanBackground)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search conversations...")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.oceanSecondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func conversationRow(_ conv: Conversation) -> some View {
        HStack(spacing: 10) {
            Image.safeSymbol(conv.symbol)
                .font(.system(size: 17))
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
                    if conv.totalCost > 0 {
                        Text(String(format: "$%.2f", conv.totalCost))
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption2)
                if !searchText.isEmpty, let match = firstMessageMatch(conv) {
                    Text(match)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            Spacer()
            Text(relativeTime(conv.lastMessageAt))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func firstMessageMatch(_ conv: Conversation) -> String? {
        let query = searchText.lowercased()
        if conv.name.lowercased().contains(query) || (conv.workingDirectory?.lowercased().contains(query) ?? false) {
            return nil
        }
        if let msg = conv.messages.first(where: { $0.text.lowercased().contains(query) }) {
            let text = msg.text.replacingOccurrences(of: "\n", with: " ")
            if let range = text.lowercased().range(of: query) {
                let start = text.index(range.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
                let end = text.index(range.upperBound, offsetBy: 50, limitedBy: text.endIndex) ?? text.endIndex
                let snippet = String(text[start..<end])
                return (start > text.startIndex ? "..." : "") + snippet + (end < text.endIndex ? "..." : "")
            }
            return String(text.prefix(80)) + (text.count > 80 ? "..." : "")
        }
        return nil
    }

    private func relativeTime(_ date: Date) -> String {
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
