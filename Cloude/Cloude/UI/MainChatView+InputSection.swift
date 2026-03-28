//  MainChatView+InputSection.swift

import SwiftUI

private struct ExpandedTopRect: Shape {
    var expansion: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY - expansion, width: rect.width, height: rect.height + expansion))
    }
}

extension MainChatView {
    @ViewBuilder
    func inputSection() -> some View {
        VStack(spacing: 0) {
            GlobalInputBar(
                inputText: $inputText,
                attachedImages: $attachedImages,
                attachedFiles: $attachedFiles,
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
                onSend: sendMessage,
                onStop: stopActiveConversation,
                onConnect: {
                    let envId = currentConversation?.environmentId ?? environmentStore.activeEnvironmentId
                    if let envId, let env = environmentStore.environments.first(where: { $0.id == envId }) {
                        connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
                    }
                },
                onRefresh: {
                    if let window = windowManager.activeWindow {
                        refreshConversation(for: window)
                    }
                },
                onTranscribe: transcribeAudio,
                onFileSearch: searchFiles,
                currentEffort: $currentEffort,
                currentModel: $currentModel
            )
            pageIndicator()
                .padding(.top, DS.Spacing.xs)
                .padding(.bottom, isKeyboardVisible ? DS.Spacing.m : DS.Spacing.xs)
        }
        .contentShape(.interaction, ExpandedTopRect(expansion: DS.Size.l))
        .onTapGesture { }
        .background(Color.themeBackground)
    }
}
