import SwiftUI

struct EnvironmentFolderPicker: View {
    @ObservedObject var environmentStore: EnvironmentStore
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var conversationStore: ConversationStore
    let conversation: Conversation
    var editable: Bool = true

    @State private var showFolderPicker = false

    private var selectedEnv: ServerEnvironment? {
        let envId = conversation.environmentId ?? environmentStore.activeEnvironmentId
        return environmentStore.environments.first { $0.id == envId }
    }

    private var isEnvConnected: Bool {
        guard let envId = conversation.environmentId ?? environmentStore.activeEnvironmentId else { return false }
        return connection.connection(for: envId)?.isConnected ?? false
    }

    private var folderDisplayName: String {
        if let dir = conversation.workingDirectory, !dir.isEmpty { return dir }
        return "Select folder"
    }

    var body: some View {
        if editable {
            editableContent
        } else {
            readOnlyContent
        }
    }

    private var editableContent: some View {
        VStack(spacing: 0) {
            Menu {
                ForEach(environmentStore.environments) { env in
                    Button(action: {
                        conversationStore.setEnvironmentId(conversation, environmentId: env.id)
                        environmentStore.setActive(env.id)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if isEnvConnected { showFolderPicker = true }
                        }
                    }) {
                        Label {
                            Text(env.host)
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
                    Text(selectedEnv?.host ?? "Select environment")
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
        }
        .background(Color.themeSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView(
                connection: connection,
                environmentId: conversation.environmentId ?? environmentStore.activeEnvironmentId
            ) { path in
                conversationStore.setWorkingDirectory(conversation, path: path)
                if conversation.isEmpty, conversation.environmentId == nil {
                    conversationStore.setEnvironmentId(conversation, environmentId: environmentStore.activeEnvironmentId)
                }
                showFolderPicker = false
            }
        }
    }

    private var readOnlyContent: some View {
        HStack(spacing: 8) {
            Image.safeSymbol(selectedEnv?.symbol ?? "server.rack")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
            Text(selectedEnv?.host ?? "")
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
            if let dir = conversation.workingDirectory, !dir.isEmpty {
                Spacer()
                Text(dir)
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.themeSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
