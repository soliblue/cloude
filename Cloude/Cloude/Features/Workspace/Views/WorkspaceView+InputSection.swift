import SwiftUI

extension WorkspaceView {
    @ViewBuilder
    func inputSection() -> some View {
        VStack(spacing: 0) {
            inputBarObserver
            windowSwitcher()
                .padding(.top, DS.Spacing.xs)
                .padding(.bottom, isKeyboardVisible ? DS.Spacing.m : DS.Spacing.xs)
        }
        .background(Color.themeBackground.ignoresSafeArea(.container, edges: .bottom).ignoresSafeArea(.keyboard))
    }

    @ViewBuilder
    private var inputBarObserver: some View {
        if let activeEnvConnection {
            EnvironmentConnectionObserver(connection: activeEnvConnection) { _ in
                inputBar
            }
        } else {
            inputBar
        }
    }

    private var inputBar: some View {
        WorkspaceInputBarObserver(
            output: activeInputOutput,
            store: store,
            conversationStore: conversationStore,
            windowManager: windowManager,
            environmentStore: environmentStore,
            activeEnvConnection: activeEnvConnection,
            currentConversation: currentConversation,
            hasEnvironmentMismatch: hasEnvironmentMismatch,
            inputTextBinding: inputTextBinding,
            attachedImagesBinding: attachedImagesBinding,
            attachedFilesBinding: attachedFilesBinding,
            currentEffortBinding: currentEffortBinding,
            currentModelBinding: currentModelBinding,
            fileSearchResults: activeEnvConnection?.files.searchResults ?? [],
            onSend: {
                dismissKeyboard()
                store.sendMessage(
                    conversationStore: conversationStore,
                    windowManager: windowManager,
                    environmentStore: environmentStore,
                    onShowSettings: onShowSettings
                )
            },
            onStop: {
                store.stopActiveConversation(environmentStore: environmentStore, windowManager: windowManager, conversationStore: conversationStore)
            },
            onConnect: {
                let runtime = store.activeRuntimeContext(
                    environmentStore: environmentStore,
                    windowManager: windowManager,
                    conversationStore: conversationStore
                )
                if let env = runtime.environment {
                    environmentStore.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
                } else {
                    onShowSettings?()
                }
            },
            onRefresh: {
                if let window = windowManager.activeWindow {
                    store.refreshConversation(for: window, environmentStore: environmentStore, conversationStore: conversationStore)
                }
            },
            onTranscribe: { audioData in
                store.transcribeAudio(
                    audioData,
                    conversationStore: conversationStore,
                    windowManager: windowManager,
                    environmentStore: environmentStore
                )
            },
            onFileSearch: { query in
                store.searchFiles(query, environmentStore: environmentStore, conversationStore: conversationStore, windowManager: windowManager)
            }
        )
    }

    private var activeInputOutput: ConversationOutput? {
        let runtime = store.activeRuntimeContext(
            environmentStore: environmentStore,
            windowManager: windowManager,
            conversationStore: conversationStore
        )
        if let convId = runtime.conversation?.id {
            return runtime.connection?.output(for: convId)
        }
        return nil
    }
}
