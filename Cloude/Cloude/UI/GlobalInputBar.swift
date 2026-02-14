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
    @Binding var suggestions: [String]
    let isConnected: Bool
    let isWhisperReady: Bool
    let isTranscribing: Bool
    let isRunning: Bool
    let skills: [Skill]
    let fileSearchResults: [String]
    let conversationDefaultEffort: EffortLevel?
    let conversationDefaultModel: ModelSelection?
    let onSend: () -> Void
    var onStop: (() -> Void)?
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
        "Check the Git tab for changes",
        "Long press a message to copy",
        "Swipe between windows below",
        "Try /compact to reduce context",
        "Swipe left here to clear text",
        "Tap the header to switch chats",
        "The heartbeat runs on a schedule",
        "Try /usage to see your stats"
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
        let mention = String(afterAt)
        let hasExtension = mention.contains(".") && !mention.hasSuffix(".")
        if hasExtension { return nil }
        return mention
    }

    private var showFileSuggestions: Bool {
        atMentionQuery != nil && !fileSearchResults.isEmpty
    }

    private var showCommandSuggestions: Bool {
        if filteredCommands.isEmpty { return false }
        if inputText.isEmpty && !isInputFocused { return false }
        if inputText.isEmpty && !suggestions.isEmpty && !isRunning { return false }
        return true
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
            }

            if !suggestions.isEmpty && inputText.count < 20 && !isRunning && !showFileSuggestions {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: {
                            inputText = suggestion
                            suggestions = []
                        }) {
                            Text(suggestion)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .animation(.easeOut(duration: 0.15), value: filteredCommands.map(\.name))
        .animation(.easeOut(duration: 0.15), value: attachedImages.map(\.id))
        .animation(.easeOut(duration: 0.15), value: attachedFiles.map(\.id))
        .animation(.easeOut(duration: 0.2), value: suggestions)
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
            if new.count >= 20 && !suggestions.isEmpty {
                withAnimation(.easeOut(duration: 0.15)) {
                    suggestions = []
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
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachedImages.isEmpty || !attachedFiles.isEmpty
    }

    private var inputRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.oceanSecondary.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .offset(x: -horizontalSwipeOffset * 0.3)
            .opacity(1 - Double(min(horizontalSwipeOffset, Constants.swipeThreshold)) / Double(Constants.swipeThreshold) * 0.5)

            actionButton
        }
    }


    private func selectFile(_ file: String) {
        guard let atIndex = inputText.lastIndex(of: "@") else { return }
        let fileName = file.lastPathComponent
        let beforeAt = String(inputText[..<atIndex])
        inputText = beforeAt + "@" + fileName + " "
    }

}
