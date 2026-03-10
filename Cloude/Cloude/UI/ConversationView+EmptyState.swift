import SwiftUI

struct EmptyConversationView: View {
    private static let characters = [
        "claude-painter",
        "claude-builder",
        "claude-scientist",
        "claude-boxer",
        "claude-explorer",
    ]

    var connection: ConnectionManager?
    var conversationStore: ConversationStore?
    var environmentStore: EnvironmentStore?
    var conversation: Conversation?

    @State private var character: String
    @State private var showFolderPicker = false

    init(
        connection: ConnectionManager? = nil,
        conversationStore: ConversationStore? = nil,
        environmentStore: EnvironmentStore? = nil,
        conversation: Conversation? = nil
    ) {
        self.connection = connection
        self.conversationStore = conversationStore
        self.environmentStore = environmentStore
        self.conversation = conversation
        _character = State(initialValue: Self.characters.randomElement()!)
    }

    private var selectedEnv: ServerEnvironment? {
        if let envId = conversation?.environmentId {
            return environmentStore?.environments.first { $0.id == envId }
        }
        return environmentStore?.environments.first { $0.id == environmentStore?.activeEnvironmentId }
    }

    private var folderDisplayName: String {
        if let dir = conversation?.workingDirectory, !dir.isEmpty {
            return dir
        }
        return "Select folder"
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
                VStack(spacing: 10) {
                    Menu {
                        ForEach(envStore.environments) { env in
                            Button(action: {
                                convStore.setEnvironmentId(conv, environmentId: env.id)
                                envStore.setActive(env.id)
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
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.oceanSecondary)
                        .clipShape(Capsule())
                    }

                    Button(action: { showFolderPicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.accentColor)
                            Text(folderDisplayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.oceanSecondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
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
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
