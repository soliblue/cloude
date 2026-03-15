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
        VStack(spacing: 16) {
            Spacer()

            if Self.animatedCharacters.contains(character) {
                AnimatedGIFView(name: "\(character)-anim", playOnce: true)
                    .frame(width: 100, height: 100)
            } else {
                Image(character)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
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
                .padding(.horizontal, 48)
                .padding(.top, 8)
            }

            if !recentConversations.isEmpty, onSelectConversation != nil {
                recentConversationsList
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentConversationsList: some View {
        VStack(spacing: 0) {
            if let onSeeAll {
                HStack {
                    Spacer()
                    Button(action: onSeeAll) {
                        HStack(spacing: 4) {
                            Text("See all")
                                .font(.caption)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }

            ForEach(recentConversations) { conv in
                Button(action: { onSelectConversation?(conv) }) {
                    HStack(spacing: 10) {
                        Image.safeSymbol(conv.symbol ?? "bubble.left")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text(conv.name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        if let symbol = envSymbol(for: conv) {
                            Image.safeSymbol(symbol)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
    }
}
