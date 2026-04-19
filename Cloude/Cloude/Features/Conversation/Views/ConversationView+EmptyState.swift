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

    var conversationStore: ConversationStore?
    var environmentStore: EnvironmentStore?
    var conversation: Conversation?
    var windowManager: WindowManager?
    var onSelectConversation: ((Conversation) -> Void)?
    var onSeeAll: (() -> Void)?

    @State private var character: String

    init(
        conversationStore: ConversationStore? = nil,
        environmentStore: EnvironmentStore? = nil,
        conversation: Conversation? = nil,
        windowManager: WindowManager? = nil,
        onSelectConversation: ((Conversation) -> Void)? = nil,
        onSeeAll: (() -> Void)? = nil
    ) {
        self.conversationStore = conversationStore
        self.environmentStore = environmentStore
        self.conversation = conversation
        self.windowManager = windowManager
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
            .prefix(3)
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
                ConversationEmptyStateAnimatedGIF(name: "\(character)-anim", playOnce: true)
                    .frame(width: DS.Size.xxl * 3 / 8, height: DS.Size.xxl * 3 / 8)
            } else {
                Image(character)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: DS.Size.xxl * 3 / 8, height: DS.Size.xxl * 3 / 8)
            }

            if let envStore = environmentStore,
               let convStore = conversationStore, let conv = conversation,
               conv.sessionId == nil {
                EnvironmentFolderPicker(
                    environmentStore: envStore,
                    conversationStore: convStore,
                    conversation: conv
                )
                .padding(.horizontal, DS.Spacing.l)
                .padding(.top, DS.Spacing.s)
            }

            if onSeeAll != nil || (!recentConversations.isEmpty && onSelectConversation != nil) {
                recentConversationsList
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentConversationsList: some View {
        VStack(spacing: DS.Spacing.s) {
            if onSeeAll != nil {
                Button(action: { onSeeAll?() }) {
                    HStack(spacing: DS.Spacing.m) {
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
                    .background(Color.themeSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
                }
                .buttonStyle(.plain)
            }
            ForEach(recentConversations) { conv in
                Button(action: { onSelectConversation?(conv) }) {
                    ConversationRowContent(
                        symbol: conv.symbol,
                        name: conv.name,
                        messageCount: conv.messages.count,
                        lastMessageAt: conv.lastMessageAt,
                        envSymbol: envSymbol(for: conv)
                    )
                    .padding(.horizontal, DS.Spacing.l)
                    .padding(.vertical, DS.Spacing.m)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.l)
    }
}
