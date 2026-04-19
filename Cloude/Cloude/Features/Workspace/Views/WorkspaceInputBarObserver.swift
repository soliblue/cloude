import SwiftUI
import CloudeShared

struct WorkspaceInputBarObserver: View {
    let output: ConversationOutput?
    let store: WorkspaceStore
    let conversationStore: ConversationStore
    let windowManager: WindowManager
    let environmentStore: EnvironmentStore
    let activeEnvConnection: EnvironmentConnection?
    let currentConversation: Conversation?
    let hasEnvironmentMismatch: Bool
    let inputTextBinding: Binding<String>
    let attachedImagesBinding: Binding<[AttachedImage]>
    let attachedFilesBinding: Binding<[AttachedFile]>
    let currentEffortBinding: Binding<EffortLevel?>
    let currentModelBinding: Binding<ModelSelection?>
    let fileSearchResults: [String]
    let onSend: () -> Void
    let onStop: () -> Void
    let onConnect: () -> Void
    let onRefresh: () -> Void
    let onTranscribe: (Data) -> Void
    let onFileSearch: (String) -> Void

    var body: some View {
        if let output {
            WorkspaceInputBarWithOutput(
                output: output,
                parent: self
            )
        } else {
            makeInputBar(isRunning: false)
        }
    }

    @ViewBuilder
    func makeInputBar(isRunning: Bool) -> some View {
        WorkspaceInputBar(
            inputText: inputTextBinding,
            attachedImages: attachedImagesBinding,
            attachedFiles: attachedFilesBinding,
            isConnected: activeEnvConnection?.isReady == true,
            isWhisperReady: activeEnvConnection?.isWhisperReady ?? false,
            isTranscribing: activeEnvConnection?.isTranscribing ?? false,
            isRunning: isRunning,
            skills: activeEnvConnection?.skills ?? [],
            fileSearchResults: fileSearchResults,
            conversationDefaultEffort: currentConversation?.defaultEffort,
            environmentMismatch: hasEnvironmentMismatch,
            isEnvironmentDisconnected: activeEnvConnection?.isReady != true,
            onSend: onSend,
            onStop: onStop,
            onConnect: onConnect,
            onRefresh: onRefresh,
            onTranscribe: onTranscribe,
            onFileSearch: onFileSearch,
            currentEffort: currentEffortBinding,
            currentModel: currentModelBinding
        )
    }
}

private struct WorkspaceInputBarWithOutput: View {
    @ObservedObject var output: ConversationOutput
    let parent: WorkspaceInputBarObserver

    var body: some View {
        parent.makeInputBar(isRunning: output.phase != .idle)
    }
}
