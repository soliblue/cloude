import SwiftUI
import CloudeShared

struct ConversationSearchSheet: View {
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    let onSelect: (Conversation) -> Void

    @State var searchText = ""
    @State private var debouncedQuery = ""
    @State private var searchTask: Task<Void, Never>?

    private var results: [Conversation] {
        let all = conversationStore.listableConversations
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
        if debouncedQuery.isEmpty { return all }
        let query = debouncedQuery.lowercased()
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
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: DS.Spacing.l) {
                    if results.isEmpty {
                        Text("No conversations found")
                            .font(.system(size: DS.Text.m))
                            .foregroundColor(.secondary)
                            .padding(.top, DS.Spacing.l)
                    }

                    ForEach(grouped, id: \.directory) { group in
                        VStack(alignment: .leading, spacing: 0) {
                            if !group.directory.isEmpty {
                                Text(group.directory.lastPathComponent)
                                    .font(.system(size: DS.Text.s))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, DS.Spacing.m)
                                    .padding(.bottom, DS.Spacing.s)
                            }

                            VStack(spacing: 0) {
                                ForEach(group.conversations) { conv in
                                    Button { onSelect(conv) } label: {
                                        conversationRow(conv)
                                    }
                                    .agenticID("conversation_search_result_\(conv.id.uuidString)")
                                    .buttonStyle(.plain)

                                    if conv.id != group.conversations.last?.id {
                                        Divider()
                                            .padding(.leading, DS.Spacing.l)
                                    }
                                }
                            }
                            .background(Color.themeSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.l)
                .padding(.top, DS.Spacing.s)
            }
            .background(Color.themeBackground)
            .searchable(text: $searchText, placement: .toolbar, prompt: "Search conversations...")
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                if newValue.isEmpty {
                    debouncedQuery = ""
                } else {
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(200))
                        if !Task.isCancelled { debouncedQuery = newValue }
                    }
                }
            }
        }
        .agenticID("conversation_search_sheet")
    }
}
