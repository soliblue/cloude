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
                                .font(.system(size: DS.Text.s))
                        } icon: {
                            Image(systemName: env.symbol)
                        }
                    }
                }
            } label: {
                HStack(spacing: DS.Spacing.s) {
                    Image.safeSymbol(selectedEnv?.symbol ?? "server.rack")
                        .font(.system(size: DS.Text.s))
                        .foregroundColor(.accentColor)
                    Text(selectedEnv?.host ?? "Select environment")
                        .font(.system(size: DS.Text.s, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: DS.Text.s))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, DS.Spacing.l)
                .padding(.vertical, DS.Spacing.m)
            }

            Divider()
                .padding(.horizontal, DS.Spacing.l)

            Button(action: { if isEnvConnected { showFolderPicker = true } }) {
                HStack(spacing: DS.Spacing.s) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: DS.Text.s))
                        .foregroundColor(.accentColor)
                    Text(folderDisplayName)
                        .font(.system(size: DS.Text.s))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: DS.Text.s))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, DS.Spacing.l)
                .padding(.vertical, DS.Spacing.m)
            }
            .buttonStyle(.plain)
            .opacity(isEnvConnected ? 1 : DS.Opacity.m)
        }
        .background(Color.themeSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l))
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
        HStack(spacing: DS.Spacing.s) {
            Image.safeSymbol(selectedEnv?.symbol ?? "server.rack")
                .font(.system(size: DS.Text.s))
                .foregroundColor(.accentColor)
            Text(selectedEnv?.host ?? "")
                .font(.system(size: DS.Text.s, design: .monospaced))
                .foregroundColor(.secondary)
            if let dir = conversation.workingDirectory, !dir.isEmpty {
                Spacer()
                Text(dir)
                    .font(.system(size: DS.Text.s, design: .monospaced))
                    .foregroundColor(.secondary.opacity(DS.Opacity.l))
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .background(Color.themeSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l))
    }
}
