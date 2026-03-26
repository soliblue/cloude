import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import Combine
import CloudeShared

struct AttachedFile: Identifiable {
    let id = UUID()
    let name: String
    let data: Data
}

struct GlobalInputBar: View {
    @Binding var inputText: String
    @Binding var attachedImages: [AttachedImage]
    @Binding var attachedFiles: [AttachedFile]
    let isConnected: Bool
    let isWhisperReady: Bool
    let isTranscribing: Bool
    let isRunning: Bool
    let skills: [Skill]
    let fileSearchResults: [String]
    let conversationDefaultEffort: EffortLevel?
    let conversationDefaultModel: ModelSelection?
    let environmentMismatch: Bool
    let isEnvironmentDisconnected: Bool
    let onSend: () -> Void
    var onStop: (() -> Void)?
    var onConnect: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onTranscribe: ((Data) -> Void)?
    var onFileSearch: ((String) -> Void)?
    @Binding var currentEffort: EffortLevel?
    @Binding var currentModel: ModelSelection?

    @State private var selectedItem: PhotosPickerItem?
    @State var showPhotoPicker = false
    @State var showFilePicker = false
    @FocusState var isInputFocused: Bool
    @StateObject var audioRecorder = AudioRecorder()
    @State var placeholderIndex = 0

    @State var swipeOffset: CGFloat = 0
    @State var horizontalSwipeOffset: CGFloat = 0
    @State var isSwipingToRecord = false
    @State var showInputBar = true
    @State var showRecordingOverlay = false
    @State private var idleTime: Date = Date()
    @State var showStopButton = false
    @State var refreshRotateTrigger = 0
    @State var sendBounceTrigger = 0
    @State var fileSearchDebounce: Task<Void, Never>?

    enum Constants {
        static let swipeThreshold: CGFloat = 60
        static let transitionDuration: Double = 0.15
        static let stopButtonDelay: TimeInterval = 3.0
        static let fileSearchDebounce: Duration = .milliseconds(150)
        static let maxImageAttachments = 5
        static let placeholderRotationInterval: TimeInterval = 8
    }

    static let placeholders = [
        "Swipe up to record a voice note",
        "Type / to see available commands",
        "Hold send for images and files",
        "Swipe left on queued messages to delete",
        "Swipe left here to clear text",
        "Add multiple environments in settings",
        "Type @ to reference a file",
        "Tap the header to switch chats",
        "Browse files in the middle tab",
        "Try /compact to reduce context"
    ]

    var body: some View {
        #if DEBUG
        let _ = Self._printChanges()
        let _ = DebugMetrics.log("InputBar", "render | focused=\(isInputFocused) running=\(isRunning) recording=\(showRecordingOverlay) swiping=\(isSwipingToRecord) transcribing=\(isTranscribing) showInput=\(showInputBar) cmds=\(showCommandSuggestions) files=\(showFileSuggestions)")
        #endif
        contentStack
            .gesture(inputBarDragGesture)
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        guard attachedImages.count < Constants.maxImageAttachments else { return }
                        withAnimation(.easeOut(duration: DS.Duration.quick)) {
                            attachedImages.append(AttachedImage(data: data, isScreenshot: false))
                        }
                    }
                    selectedItem = nil
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                if let urls = try? result.get() {
                    for url in urls {
                        guard url.startAccessingSecurityScopedResource() else { continue }
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let data = try? Data(contentsOf: url) {
                            withAnimation(.easeOut(duration: DS.Duration.quick)) {
                                attachedFiles.append(AttachedFile(name: url.lastPathComponent, data: data))
                            }
                        }
                    }
                }
            }
            .onChange(of: inputText) { old, new in
                idleTime = Date()
                showStopButton = false
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
                    showStopButton = false
                } else {
                    idleTime = Date()
                }
            }
            .task(id: isRunning) {
                guard isRunning else {
                    showStopButton = false
                    return
                }
                idleTime = Date()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    if !Task.isCancelled && isRunning && !isInputFocused && Date().timeIntervalSince(idleTime) >= Constants.stopButtonDelay {
                        withAnimation(.quickTransition) {
                            showStopButton = true
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
