import SwiftUI

struct EnvironmentFolderPicker: View {
    let environmentStore: EnvironmentStore
    let conversationStore: ConversationStore
    let conversation: Conversation
    var editable: Bool = true

    @State private var showFolderPicker = false
    @State private var pendingConnectionEnvId: UUID?

    private var isConnecting: Bool { pendingConnectionEnvId != nil }
    var currentConversation: Conversation {
        conversationStore.conversation(withId: conversation.id) ?? conversation
    }

    var selectedEnv: ServerEnvironment? {
        environmentStore.environments.first { $0.id == currentConversation.environmentId }
    }

    private var isEnvAuthenticated: Bool {
        environmentStore.connectionStore.connection(for: currentConversation.environmentId)?.isReady == true
    }

    private var folderDisplayName: String {
        if let dir = currentConversation.workingDirectory, !dir.isEmpty { return dir }
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
                        if currentConversation.environmentId != env.id {
                            conversationStore.setWorkingDirectory(currentConversation, path: nil)
                        }
                        conversationStore.setEnvironmentId(currentConversation, environmentId: env.id)
                        if environmentStore.connectionStore.connection(for: env.id)?.isReady == true {
                            DispatchQueue.main.asyncAfter(deadline: .now() + DS.Delay.m) {
                                showFolderPicker = true
                            }
                        } else {
                            pendingConnectionEnvId = env.id
                            environmentStore.connectionStore.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
                            DispatchQueue.main.asyncAfter(deadline: .now() + DS.Delay.xxl) {
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
                        .lineLimit(1)
                        .truncationMode(.middle)
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

            Button(action: { if isEnvAuthenticated { showFolderPicker = true } }) {
                HStack(spacing: DS.Spacing.s) {
                    if isConnecting {
                        ProgressView()
                            .scaleEffect(DS.Scale.s)
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
            .opacity(isEnvAuthenticated || isConnecting ? 1 : DS.Opacity.m)
        }
        .background(Color.themeSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l))
        .onReceive(environmentStore.connectionStore.events) { event in
            if case .authenticated(let envId) = event,
               envId == pendingConnectionEnvId,
               environmentStore.connectionStore.connection(for: envId)?.isReady == true {
                pendingConnectionEnvId = nil
                showFolderPicker = true
            }
        }
        .sheet(isPresented: $showFolderPicker) {
            FolderPickerView(
                environmentStore: environmentStore,
                environmentId: currentConversation.environmentId
            ) { path in
                conversationStore.setWorkingDirectory(currentConversation, path: path)
                showFolderPicker = false
            }
        }
    }
}
