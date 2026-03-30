import SwiftUI

struct EnvironmentFolderPicker: View {
    @ObservedObject var environmentStore: EnvironmentStore
    @ObservedObject var connection: ConnectionManager
    @ObservedObject var conversationStore: ConversationStore
    let conversation: Conversation
    var editable: Bool = true

    @State private var showFolderPicker = false
    @State private var pendingConnectionEnvId: UUID?

    private var isConnecting: Bool { pendingConnectionEnvId != nil }

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
                        if connection.connection(for: env.id)?.isConnected ?? false {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showFolderPicker = true
                            }
                        } else {
                            pendingConnectionEnvId = env.id
                            connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                if pendingConnectionEnvId == env.id {
                                    pendingConnectionEnvId = nil
                                }
                            }
                        }
                    }) {
                        Label {
                            Text(env.host)
                                .font(.system(size: DS.Text.m))
                        } icon: {
                            Image(systemName: env.symbol)
                        }
                    }
                }
            } label: {
                HStack(spacing: DS.Spacing.s) {
                    Image.safeSymbol(selectedEnv?.symbol ?? "server.rack")
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.accentColor)
                    Text(selectedEnv?.host ?? "Select environment")
                        .font(.system(size: DS.Text.m, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, DS.Spacing.l)
                .padding(.vertical, DS.Spacing.m)
            }

            Divider()
                .padding(.horizontal, DS.Spacing.l)

            Button(action: { if isEnvConnected { showFolderPicker = true } }) {
                HStack(spacing: DS.Spacing.s) {
                    if isConnecting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: DS.Text.m, height: DS.Text.m)
                    } else {
                        Image(systemName: "folder.fill")
                            .font(.system(size: DS.Text.m))
                            .foregroundColor(.accentColor)
                    }
                    Text(isConnecting ? "Connecting..." : folderDisplayName)
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    if !isConnecting {
                        Image(systemName: "chevron.right")
                            .font(.system(size: DS.Text.m))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, DS.Spacing.l)
                .padding(.vertical, DS.Spacing.m)
            }
            .buttonStyle(.plain)
            .disabled(isConnecting)
            .opacity(isEnvConnected || isConnecting ? 1 : DS.Opacity.m)
        }
        .background(Color.themeSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l))
        .onReceive(connection.events) { event in
            if case .authenticated = event, let envId = pendingConnectionEnvId {
                if connection.connection(for: envId)?.isConnected ?? false {
                    pendingConnectionEnvId = nil
                    showFolderPicker = true
                }
            }
        }
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
                .font(.system(size: DS.Text.m))
                .foregroundColor(.accentColor)
            Text(selectedEnv?.host ?? "")
                .font(.system(size: DS.Text.m, design: .monospaced))
                .foregroundColor(.secondary)
            if let dir = conversation.workingDirectory, !dir.isEmpty {
                Spacer()
                Text(dir)
                    .font(.system(size: DS.Text.m, design: .monospaced))
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
