import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

extension ConversationInputBar {
    var body: some View {
        #if DEBUG
        let _ = DebugMetrics.log("InputBar", "render | focused=\(isInputFocused) running=\(isRunning) phase=\(phase) transcribing=\(isTranscribing) cmds=\(isShowingCommandSuggestions) files=\(isShowingFileSuggestions)")
        #endif
        return contentStack
            .gesture(inputBarDragGesture)
            .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        guard attachedImages.count < Constants.maxImageAttachments else { return }
                        withAnimation(.easeOut(duration: DS.Duration.s)) {
                            attachedImages.append(AttachedImage(data: data, isScreenshot: false))
                        }
                    }
                    selectedItem = nil
                }
            }
            .fileImporter(isPresented: $isShowingFilePicker, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                if let urls = try? result.get() {
                    for url in urls {
                        guard url.startAccessingSecurityScopedResource() else { continue }
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let data = try? Data(contentsOf: url) {
                            withAnimation(.easeOut(duration: DS.Duration.s)) {
                                attachedFiles.append(AttachedFile(name: url.lastPathComponent, data: data))
                            }
                        }
                    }
                }
            }
            .onChange(of: inputText) { _, _ in
                idleTime = Date()
                isShowingStopButton = false
                if let query = atMentionQuery {
                    fileSearchDebounce?.cancel()
                    fileSearchDebounce = Task {
                        try? await Task.sleep(for: Constants.fileSearchDebounce)
                        if !Task.isCancelled {
                            onFileSearch?(query)
                        }
                    }
                }
            }
            .onChange(of: isInputFocused) { _, focused in
                if focused {
                    isShowingStopButton = false
                } else {
                    idleTime = Date()
                }
            }
            .task(id: isRunning) {
                guard isRunning else {
                    isShowingStopButton = false
                    return
                }
                idleTime = Date()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    if !Task.isCancelled && isRunning && !isInputFocused && Date().timeIntervalSince(idleTime) >= Constants.stopButtonDelay {
                        withAnimation(.quickTransition) {
                            isShowingStopButton = true
                        }
                    }
                }
            }
            .onReceive(AudioRecorder.pendingAudioCleared) { _ in
                audioRecorder.hasPendingAudio = false
            }
            .onReceive(AudioRecorder.transcriptionFailed) { _ in
                audioRecorder.hasPendingAudio = true
            }
    }
}
