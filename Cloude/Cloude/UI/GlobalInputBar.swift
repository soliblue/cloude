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
    @State private var placeholderIndex = Int.random(in: 0..<Self.placeholders.count)
    @State private var textFieldId = UUID()
    @State var swipeOffset: CGFloat = 0
    @State var horizontalSwipeOffset: CGFloat = 0
    @State var isSwipingToRecord = false
    @State var showInputBar = true
    @State var showRecordingOverlay = false
    @State private var idleTime: Date = Date()
    @State var showStopButton = false
    @State private var fileSearchDebounce: Task<Void, Never>?

    enum Constants {
        static let swipeThreshold: CGFloat = 60
        static let transitionDuration: Double = 0.15
        static let stopButtonDelay: TimeInterval = 3.0
        static let fileSearchDebounceNanos: UInt64 = 150_000_000
        static let maxImageAttachments = 5
        static let placeholderRotationInterval: TimeInterval = 8
    }

    private static let placeholders = [
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

    private var placeholder: String {
        Self.placeholders[placeholderIndex % Self.placeholders.count]
    }

    private var primaryCommands: [SlashCommand] {
        builtInCommands + skills.compactMap { SlashCommand.fromSkill($0).first }
    }

    private var allCommandsWithAliases: [SlashCommand] {
        builtInCommands + skills.flatMap { SlashCommand.fromSkill($0) }
    }

    private var slashQuery: String? {
        guard let slashIndex = inputText.lastIndex(of: "/") else { return nil }
        let afterSlash = inputText[inputText.index(after: slashIndex)...]
        if afterSlash.contains(where: { $0 == " " || $0 == "\n" }) { return nil }
        return String(afterSlash).lowercased()
    }

    private var filteredCommands: [SlashCommand] {
        if inputText.isEmpty {
            return primaryCommands
        }
        guard let query = slashQuery else { return [] }
        if query.isEmpty {
            return primaryCommands
        }
        if let match = allCommandsWithAliases.first(where: { $0.name.lowercased() == query }) {
            return [match]
        }
        return primaryCommands.filter { $0.name.lowercased().hasPrefix(query) }
    }

    private var isSlashCommand: Bool {
        inputText.hasPrefix("/")
    }

    private var atMentionQuery: String? {
        guard let atIndex = inputText.lastIndex(of: "@") else { return nil }
        let afterAt = inputText[inputText.index(after: atIndex)...]
        if afterAt.contains(where: { $0 == " " || $0 == "\n" }) { return nil }
        return String(afterAt)
    }

    private var showFileSuggestions: Bool {
        atMentionQuery != nil && !fileSearchResults.isEmpty
    }

    private var showCommandSuggestions: Bool {
        if filteredCommands.isEmpty { return false }
        if inputText.isEmpty && !isInputFocused { return false }
        if inputText.isEmpty && !isRunning { return false }
        return true
    }

    private var historySuggestions: [String] {
        guard !showFileSuggestions, !showCommandSuggestions else { return [] }
        return MessageHistory.suggestions(for: inputText)
    }

    var body: some View {
        VStack(spacing: 0) {
            if audioRecorder.hasPendingAudio && !audioRecorder.isRecording && !isTranscribing {
                PendingAudioBanner(
                    onResend: resendPendingAudio,
                    onDiscard: { audioRecorder.clearPendingAudio() }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if showFileSuggestions {
                FileSuggestionsList(
                    files: fileSearchResults,
                    onSelect: selectFile
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showCommandSuggestions {
                SlashCommandSuggestions(
                    commands: filteredCommands,
                    onSelect: { command in
                        inputText = "/\(command.resolvesTo ?? command.name)"
                        if !command.hasParameters {
                            isInputFocused = false
                            onSend()
                        } else {
                            inputText += " "
                            isInputFocused = true
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if !historySuggestions.isEmpty {
                HistorySuggestions(
                    suggestions: historySuggestions,
                    onSelect: { text in
                        inputText = text
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if !attachedImages.isEmpty {
                ImageAttachmentStrip(
                    images: attachedImages,
                    onRemove: { id in
                        withAnimation(.easeOut(duration: 0.15)) {
                            attachedImages.removeAll { $0.id == id }
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if !attachedFiles.isEmpty {
                FileAttachmentStrip(
                    files: attachedFiles,
                    onRemove: { id in
                        withAnimation(.easeOut(duration: 0.15)) {
                            attachedFiles.removeAll { $0.id == id }
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            ZStack(alignment: .bottom) {
                inputRow
                    .opacity((showInputBar && !isTranscribing) ? 1.0 - Double(min(swipeOffset, Constants.swipeThreshold)) / Double(Constants.swipeThreshold) * 0.7 : 0)
                    .animation(.easeOut(duration: Constants.transitionDuration), value: showInputBar)
                    .animation(.easeOut(duration: Constants.transitionDuration), value: isTranscribing)

                if showRecordingOverlay || isSwipingToRecord || isTranscribing {
                    RecordingOverlayView(
                        audioLevel: audioRecorder.audioLevel,
                        isTranscribing: isTranscribing,
                        onStop: stopRecording
                    )
                    .offset(y: (showRecordingOverlay || isTranscribing) ? 0 : max(0, Constants.swipeThreshold - swipeOffset))
                    .opacity((showRecordingOverlay || isTranscribing) ? 1 : Double(min(swipeOffset, Constants.swipeThreshold)) / Double(Constants.swipeThreshold))
                    .animation(.easeOut(duration: Constants.transitionDuration), value: showRecordingOverlay)
                    .animation(.easeOut(duration: Constants.transitionDuration), value: isTranscribing)
                }
            }
            .padding(.bottom, 12)
        }
        .animation(.easeOut(duration: 0.15), value: filteredCommands.map(\.name))
        .animation(.easeOut(duration: 0.15), value: attachedImages.map(\.id))
        .animation(.easeOut(duration: 0.15), value: attachedFiles.map(\.id))
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
                textFieldId = UUID()
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

    var canSend: Bool {
        if environmentMismatch { return false }
        return !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachedImages.isEmpty || !attachedFiles.isEmpty
    }

    private var inputRow: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                if inputText.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.secondary)
                        .id(placeholderIndex)
                        .transition(.opacity)
                }
                TextField("", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .foregroundColor(isSlashCommand ? .cyan : .primary)
                    .onSubmit { if canSend { onSend() } }
                    .id(textFieldId)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.oceanSecondary.opacity(0.8))
            .offset(x: -horizontalSwipeOffset * 0.3)
            .opacity(1 - Double(min(horizontalSwipeOffset, Constants.swipeThreshold)) / Double(Constants.swipeThreshold) * 0.5)

            actionButton
        }
        .fixedSize(horizontal: false, vertical: true)
    }


    private func selectFile(_ file: String) {
        guard let atIndex = inputText.lastIndex(of: "@") else { return }
        let beforeAt = String(inputText[..<atIndex])
        inputText = beforeAt + file + " "
    }

}
