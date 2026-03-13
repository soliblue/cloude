import SwiftUI

struct EmptyConversationView: View {
    private static let characters = [
        "claude-painter",
        "claude-builder",
        "claude-boxer",
        "claude-explorer",
    ]

    var connection: ConnectionManager?
    var conversationStore: ConversationStore?
    var environmentStore: EnvironmentStore?
    var conversation: Conversation?
    var windowManager: WindowManager?
    var window: ChatWindow?
    var onSelectConversation: ((Conversation) -> Void)?

    @State private var character: String
    @State private var showFolderPicker = false

    init(
        connection: ConnectionManager? = nil,
        conversationStore: ConversationStore? = nil,
        environmentStore: EnvironmentStore? = nil,
        conversation: Conversation? = nil,
        windowManager: WindowManager? = nil,
        window: ChatWindow? = nil,
        onSelectConversation: ((Conversation) -> Void)? = nil
    ) {
        self.connection = connection
        self.conversationStore = conversationStore
        self.environmentStore = environmentStore
        self.conversation = conversation
        self.windowManager = windowManager
        self.window = window
        self.onSelectConversation = onSelectConversation
        _character = State(initialValue: Self.characters.randomElement()!)
    }

    private var selectedEnv: ServerEnvironment? {
        if let envId = conversation?.environmentId {
            return environmentStore?.environments.first { $0.id == envId }
        }
        return environmentStore?.environments.first { $0.id == environmentStore?.activeEnvironmentId }
    }

    private var isEnvConnected: Bool {
        guard let envId = conversation?.environmentId ?? environmentStore?.activeEnvironmentId else { return false }
        return connection?.connection(for: envId)?.isConnected ?? false
    }

    private var folderDisplayName: String {
        if let dir = conversation?.workingDirectory, !dir.isEmpty {
            return dir
        }
        return "Select folder"
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
        VStack(spacing: 16) {
            Spacer()

            Image(character)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)

            if let envStore = environmentStore, let conn = connection,
               let convStore = conversationStore, let conv = conversation,
               conv.sessionId == nil {
                VStack(spacing: 0) {
                    Menu {
                        ForEach(envStore.environments) { env in
                            Button(action: {
                                convStore.setEnvironmentId(conv, environmentId: env.id)
                                envStore.setActive(env.id)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    if isEnvConnected { showFolderPicker = true }
                                }
                            }) {
                                Label {
                                    Text("\(env.host):\(env.port)")
                                } icon: {
                                    Image(systemName: env.symbol)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image.safeSymbol(selectedEnv?.symbol ?? "server.rack")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                            Text(selectedEnv.map { "\($0.host):\($0.port)" } ?? "Select environment")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }

                    Divider()
                        .padding(.horizontal, 14)

                    Button(action: { if isEnvConnected { showFolderPicker = true } }) {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                            Text(folderDisplayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .opacity(isEnvConnected ? 1 : 0.4)
                    .sheet(isPresented: $showFolderPicker) {
                        FolderPickerView(
                            connection: conn,
                            environmentId: conv.environmentId ?? envStore.activeEnvironmentId,
                            onSelect: { path in
                                convStore.setWorkingDirectory(conv, path: path)
                                showFolderPicker = false
                            }
                        )
                    }
                }
                .background(Color.oceanSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 48)
                .padding(.top, 8)
            }

            if !recentConversations.isEmpty, onSelectConversation != nil {
                recentConversationsList
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentConversationsList: some View {
        VStack(spacing: 0) {
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
