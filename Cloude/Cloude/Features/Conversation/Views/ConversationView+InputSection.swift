import SwiftUI
import CloudeShared

extension ConversationView {
    var runtimeEnvironmentId: UUID? {
        effectiveConversation?.environmentId ?? environmentStore.activeEnvironmentId
    }

    var runtimeEnvironment: ServerEnvironment? {
        environmentStore.environments.first { $0.id == runtimeEnvironmentId }
    }

    var runtimeConnection: Connection? {
        environmentStore.connectionStore.connection(for: runtimeEnvironmentId)
    }

    var runtimeWorkingDirectory: String? {
        effectiveConversation?.workingDirectory ?? runtimeConnection?.defaultWorkingDirectory?.nilIfEmpty
    }

    var hasEnvironmentMismatch: Bool {
        if effectiveConversation?.environmentId != nil {
            return runtimeConnection?.isReady != true
        }
        return false
    }

    var inputTextBinding: Binding<String> {
        Binding(
            get: { effectiveConversation?.draft.text ?? "" },
            set: { newValue in
                if let conversation = effectiveConversation {
                    store.mutateDraft(conversation.id) { $0.text = newValue }
                }
            }
        )
    }

    var attachedImagesBinding: Binding<[AttachedImage]> {
        Binding(
            get: { effectiveConversation?.draft.images ?? [] },
            set: { newValue in
                if let conversation = effectiveConversation {
                    store.mutateDraft(conversation.id) { $0.images = newValue }
                }
            }
        )
    }

    var attachedFilesBinding: Binding<[AttachedFile]> {
        Binding(
            get: { effectiveConversation?.draft.files ?? [] },
            set: { newValue in
                if let conversation = effectiveConversation {
                    store.mutateDraft(conversation.id) { $0.files = newValue }
                }
            }
        )
    }

    var currentEffortBinding: Binding<EffortLevel?> {
        Binding(
            get: { effectiveConversation?.defaultEffort },
            set: { newValue in
                if let conversation = effectiveConversation {
                    store.setDefaultEffort(conversation, effort: newValue)
                }
            }
        )
    }

    var currentModelBinding: Binding<ModelSelection?> {
        Binding(
            get: { effectiveConversation?.defaultModel },
            set: { newValue in
                if let conversation = effectiveConversation {
                    store.setDefaultModel(conversation, model: newValue)
                }
            }
        )
    }

    @ViewBuilder
    func conversationInputSection(output: ConversationOutput?) -> some View {
        if let connection = runtimeConnection {
            ConnectionObserver(connection: connection) { _ in
                inputBar(
                    output: output,
                    connection: connection,
                    environment: runtimeEnvironment,
                    workingDirectory: runtimeWorkingDirectory
                )
            }
        } else {
            inputBar(
                output: output,
                connection: runtimeConnection,
                environment: runtimeEnvironment,
                workingDirectory: runtimeWorkingDirectory
            )
        }
    }

    private func inputBar(
        output: ConversationOutput?,
        connection: Connection?,
        environment: ServerEnvironment?,
        workingDirectory: String?
    ) -> some View {
        ConversationInputBarObserver(
            output: output,
            connection: connection,
            hasEnvironmentMismatch: hasEnvironmentMismatch,
            inputTextBinding: inputTextBinding,
            attachedImagesBinding: attachedImagesBinding,
            attachedFilesBinding: attachedFilesBinding,
            currentEffortBinding: currentEffortBinding,
            currentModelBinding: currentModelBinding,
            fileSearchResults: connection?.files.searchResults ?? [],
            onSend: {
                onInteraction?()
                onSend?()
            },
            onStop: {
                onStop?()
            },
            onConnect: {
                if let environment = environment {
                    environmentStore.connectionStore.connectEnvironment(
                        environment.id,
                        host: environment.host,
                        port: environment.port,
                        token: environment.token,
                        symbol: environment.symbol
                    )
                } else {
                    onShowSettings?()
                }
            },
            onRefresh: {
                onRefresh?()
            },
            onTranscribe: { audioData in
                connection?.transcription.transcribe(audioBase64: audioData.base64EncodedString())
            },
            onFileSearch: { query in
                if let workingDirectory,
                   !workingDirectory.isEmpty {
                    connection?.files.search(query: query, workingDirectory: workingDirectory)
                } else {
                    connection?.files.clearSearch()
                }
            }
        )
        .background(
            Color.themeBackground
                .ignoresSafeArea(.container, edges: .bottom)
                .ignoresSafeArea(.keyboard)
        )
    }
}
