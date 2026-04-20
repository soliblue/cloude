import SwiftUI
import CloudeShared

struct ConversationInputBarObserver: View {
    let output: ConversationOutput?
    let connection: Connection?
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
            ConversationInputBarWithOutput(
                output: output,
                parent: self
            )
        } else {
            makeInputBar(isRunning: false)
        }
    }

    @ViewBuilder
    func makeInputBar(isRunning: Bool) -> some View {
        ConversationInputBar(
            inputText: inputTextBinding,
            attachedImages: attachedImagesBinding,
            attachedFiles: attachedFilesBinding,
            isConnected: connection?.isReady == true,
            isWhisperReady: connection?.transcription.isReady ?? false,
            isTranscribing: connection?.transcription.isTranscribing ?? false,
            isRunning: isRunning,
            skills: connection?.skills ?? [],
            fileSearchResults: fileSearchResults,
            environmentMismatch: hasEnvironmentMismatch,
            isEnvironmentDisconnected: connection?.isReady != true,
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

private struct ConversationInputBarWithOutput: View {
    @ObservedObject var output: ConversationOutput
    let parent: ConversationInputBarObserver

    var body: some View {
        parent.makeInputBar(isRunning: output.phase != .idle)
    }
}
