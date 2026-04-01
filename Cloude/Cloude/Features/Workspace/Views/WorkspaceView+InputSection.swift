//  WorkspaceView+InputSection.swift

import SwiftUI

private struct ExpandedTopRect: Shape {
    var expansion: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY - expansion, width: rect.width, height: rect.height + expansion))
    }
}

extension WorkspaceView {
    @ViewBuilder
    func inputSection() -> some View {
        VStack(spacing: 0) {
            WorkspaceInputBar(
                inputText: inputTextBinding,
                attachedImages: attachedImagesBinding,
                attachedFiles: attachedFilesBinding,
                isConnected: activeEnvConnection?.isAuthenticated ?? false,
                isWhisperReady: activeEnvConnection?.isWhisperReady ?? false,
                isTranscribing: activeEnvConnection?.isTranscribing ?? false,
                isRunning: activeConversationIsRunning,
                skills: activeEnvConnection?.skills ?? [],
                fileSearchResults: fileSearchResults,
                conversationDefaultEffort: currentConversation?.defaultEffort,
                conversationDefaultModel: currentConversation?.defaultModel,
                environmentMismatch: hasEnvironmentMismatch,
                isEnvironmentDisconnected: activeEnvConnection?.isAuthenticated != true,
                onSend: {
                    dismissKeyboard()
                    store.sendMessage(
                        connection: connection,
                        conversationStore: conversationStore,
                        windowManager: windowManager,
                        environmentStore: environmentStore,
                        onShowPlans: onShowPlans,
                        onShowMemories: onShowMemories,
                        onShowSettings: onShowSettings,
                        onShowWhiteboard: onShowWhiteboard
                    )
                },
                onStop: {
                    store.stopActiveConversation(connection: connection, windowManager: windowManager)
                },
                onConnect: {
                    let envId = currentConversation?.environmentId ?? environmentStore.activeEnvironmentId
                    if let envId, let env = environmentStore.environments.first(where: { $0.id == envId }) {
                        connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
                    }
                },
                onRefresh: {
                    if let window = windowManager.activeWindow {
                        store.refreshConversation(for: window, connection: connection, conversationStore: conversationStore)
                    }
                },
                onTranscribe: { audioData in
                    store.transcribeAudio(
                        audioData,
                        connection: connection,
                        conversationStore: conversationStore,
                        windowManager: windowManager,
                        environmentStore: environmentStore
                    )
                },
                onFileSearch: { query in
                    store.searchFiles(query, connection: connection, conversationStore: conversationStore, windowManager: windowManager)
                },
                currentEffort: currentEffortBinding,
                currentModel: currentModelBinding
            )
            windowSwitcher()
                .padding(.top, DS.Spacing.xs)
                .padding(.bottom, isKeyboardVisible ? DS.Spacing.m : DS.Spacing.xs)
        }
        .contentShape(.interaction, ExpandedTopRect(expansion: DS.Size.l))
        .onTapGesture { }
        .background(Color.themeBackground.ignoresSafeArea(.container, edges: .bottom).ignoresSafeArea(.keyboard))
    }
}
