import SwiftUI
import CloudeShared

struct ConversationSearchSheet: View {
    @ObservedObject var conversationStore: ConversationStore
    @ObservedObject var windowManager: WindowManager
    let onSelect: (Conversation) -> Void

    @State var searchText = ""
    @State private var isSearchFocused = false
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
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: DS.Spacing.l) {
                    if results.isEmpty {
                        Text("No conversations found")
                            .font(.system(size: DS.Text.m))
                            .foregroundColor(.secondary)
                            .padding(.top, DS.Spacing.xxl)
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
                                    .buttonStyle(.plain)

                                    if conv.id != group.conversations.last?.id {
                                        Divider()
                                            .padding(.leading, DS.Spacing.xxl)
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
            .searchable(text: $searchText, isPresented: $isSearchFocused, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search conversations...")
            .onAppear { isSearchFocused = true }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.themeSecondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.Icon.s, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
