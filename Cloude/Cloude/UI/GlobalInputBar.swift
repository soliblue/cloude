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
    @State var placeholderIndex = Int.random(in: 0..<Self.placeholders.count)

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
        static let fileSearchDebounceNanos: UInt64 = 150_000_000
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
        contentStack
            .gesture(inputBarDragGesture)
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        guard attachedImages.count < Constants.maxImageAttachments else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
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
                            withAnimation(.easeOut(duration: 0.15)) {
                                attachedFiles.append(AttachedFile(name: url.lastPathComponent, data: data))
                            }
                        }
                    }
                }
            }
            .onChange(of: inputText) { old, new in
                idleTime = Date()
                showStopButton = false
                if !old.isEmpty && new.isEmpty {
                    placeholderIndex = Int.random(in: 0..<Self.placeholders.count)
                }
                if let query = atMentionQuery {
                    fileSearchDebounce?.cancel()
                    fileSearchDebounce = Task {
                        try? await Task.sleep(nanoseconds: Constants.fileSearchDebounceNanos)
                        if !Task.isCancelled {
                            onFileSearch?(query)
                        }
                    }
                }
            }
            .onReceive(Timer.publish(every: Constants.placeholderRotationInterval, on: .main, in: .common).autoconnect()) { _ in
                if inputText.isEmpty {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        placeholderIndex = (placeholderIndex + 1) % Self.placeholders.count
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
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                if isRunning && !isInputFocused && Date().timeIntervalSince(idleTime) >= Constants.stopButtonDelay {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showStopButton = true
                    }
                }
            }
            .onChange(of: isRunning) { _, running in
                if !running {
                    showStopButton = false
                } else {
                    idleTime = Date()
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
