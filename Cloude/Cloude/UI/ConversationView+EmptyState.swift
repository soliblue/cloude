import SwiftUI

struct EmptyConversationView: View {
    private static let characters = [
        "claude-painter",
        "claude-builder",
        "claude-boxer",
        "claude-explorer",
    ]

    private static let animatedCharacters: Set<String> = [
        "claude-boxer",
    ]

    var connection: ConnectionManager?
    var conversationStore: ConversationStore?
    var environmentStore: EnvironmentStore?
    var conversation: Conversation?
    var windowManager: WindowManager?
    var window: ChatWindow?
    var onSelectConversation: ((Conversation) -> Void)?
    var onSeeAll: (() -> Void)?

    @State private var character: String

    init(
        connection: ConnectionManager? = nil,
        conversationStore: ConversationStore? = nil,
        environmentStore: EnvironmentStore? = nil,
        conversation: Conversation? = nil,
        windowManager: WindowManager? = nil,
        window: ChatWindow? = nil,
        onSelectConversation: ((Conversation) -> Void)? = nil,
        onSeeAll: (() -> Void)? = nil
    ) {
        self.connection = connection
        self.conversationStore = conversationStore
        self.environmentStore = environmentStore
        self.conversation = conversation
        self.windowManager = windowManager
        self.window = window
        self.onSelectConversation = onSelectConversation
        self.onSeeAll = onSeeAll
        _character = State(initialValue: Self.characters.randomElement()!)
    }

    private var recentConversations: [Conversation] {
        guard let store = conversationStore else { return [] }
        let openIds = windowManager?.openConversationIds ?? []
        return store.listableConversations
            .filter { !$0.isEmpty && !openIds.contains($0.id) }
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
            .prefix(5)
            .map { $0 }
    }

    private func envSymbol(for conv: Conversation) -> String? {
        guard let envId = conv.environmentId else { return nil }
        return environmentStore?.environments.first { $0.id == envId }?.symbol
    }

    var body: some View {
        VStack(spacing: DS.Spacing.l) {
            Spacer()

            if Self.animatedCharacters.contains(character) {
                AnimatedGIFView(name: "\(character)-anim", playOnce: true)
                    .frame(width: DS.Size.chart / 2, height: DS.Size.chart / 2)
            } else {
                Image(character)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: DS.Size.chart / 2, height: DS.Size.chart / 2)
            }

            if let envStore = environmentStore, let conn = connection,
               let convStore = conversationStore, let conv = conversation,
               conv.sessionId == nil {
                EnvironmentFolderPicker(
                    environmentStore: envStore,
                    connection: conn,
                    conversationStore: convStore,
                    conversation: conv
                )
                .padding(.horizontal, DS.Spacing.xxl)
                .padding(.top, DS.Spacing.s)
            }

            if onSeeAll != nil {
                searchButton
            }

            if !recentConversations.isEmpty, onSelectConversation != nil {
                recentConversationsList
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchButton: some View {
        Button(action: { onSeeAll?() }) {
            HStack(spacing: DS.Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: DS.Text.m))
                    .foregroundColor(.secondary)
                Text("Search conversations...")
                    .font(.system(size: DS.Text.m))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.m)
            .background(Color.secondary.opacity(DS.Opacity.subtle))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.top, DS.Spacing.s)
    }

    private var recentConversationsList: some View {
        VStack(spacing: 0) {
            ForEach(recentConversations) { conv in
                Button(action: { onSelectConversation?(conv) }) {
                    HStack(spacing: DS.Spacing.m) {
                        Image.safeSymbol(conv.symbol ?? "bubble.left")
                            .font(.system(size: DS.Text.m))
                            .foregroundColor(.secondary)
                            .frame(width: DS.Size.divider)
                        Text(conv.name)
                            .font(.system(size: DS.Text.m))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        if let symbol = envSymbol(for: conv) {
                            Image.safeSymbol(symbol)
                                .font(.system(size: DS.Text.s))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.vertical, DS.Spacing.m)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.top, DS.Spacing.s)
    }
}
