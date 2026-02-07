import SwiftUI
import UIKit
import PhotosUI
import Combine
import CloudeShared

struct GlobalInputBar: View {
    @Binding var inputText: String
    @Binding var selectedImageData: Data?
    let isConnected: Bool
    let isWhisperReady: Bool
    let isTranscribing: Bool
    let isRunning: Bool
    let skills: [Skill]
    let fileSearchResults: [String]
    let conversationDefaultEffort: EffortLevel?
    let onSend: () -> Void
    let onEffortChange: ((EffortLevel?) -> Void)?
    var onStop: (() -> Void)?
    var onTranscribe: ((Data) -> Void)?
    var onFileSearch: ((String) -> Void)?

    @State private var selectedItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @FocusState private var isInputFocused: Bool
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var placeholderIndex = Int.random(in: 0..<20)
    @State private var textFieldId = UUID()
    @State private var swipeOffset: CGFloat = 0
    @State private var horizontalSwipeOffset: CGFloat = 0
    @State private var isSwipingToRecord = false
    @State private var showInputBar = true
    @State private var showRecordingOverlay = false
    @State private var idleTime: Date = Date()
    @State private var showStopButton = false
    @State private var fileSearchDebounce: Task<Void, Never>?
    @State private var currentEffort: EffortLevel?

    private let swipeThreshold: CGFloat = 60
    private let transitionDuration: Double = 0.15
    private let stopButtonDelay: TimeInterval = 3.0

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
        "Try /cost to see usage stats"
    ]

    private var placeholder: String {
        Self.placeholders[placeholderIndex % Self.placeholders.count]
    }

    private var primaryCommands: [SlashCommand] {
        builtInCommands + skills.map { SlashCommand.fromSkill($0).first! }
    }

    private var allCommandsWithAliases: [SlashCommand] {
        builtInCommands + skills.flatMap { SlashCommand.fromSkill($0) }
    }

    private var filteredCommands: [SlashCommand] {
        guard inputText.hasPrefix("/") else { return [] }
        let query = String(inputText.dropFirst()).lowercased()
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
        let endIndex = afterAt.firstIndex(where: { $0 == " " || $0 == "\n" }) ?? afterAt.endIndex
        let mention = String(afterAt[..<endIndex])
        if mention.isEmpty { return nil }
        let hasExtension = mention.contains(".") && !mention.hasSuffix(".")
        if hasExtension { return nil }
        return mention
    }

    private var showFileSuggestions: Bool {
        atMentionQuery != nil && !fileSearchResults.isEmpty
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
            } else if !filteredCommands.isEmpty {
                SlashCommandSuggestions(
                    commands: filteredCommands,
                    onSelect: { command in
                        inputText = "/\(command.resolvesTo ?? command.name)"
                        if !command.hasParameters {
                            onSend()
                        } else {
                            inputText += " "
                            isInputFocused = true
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            ZStack(alignment: .bottom) {
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

                        if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Button(action: { selectedImageData = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.accentColor)
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .offset(x: -horizontalSwipeOffset * 0.3)
                    .opacity(1 - Double(min(horizontalSwipeOffset, swipeThreshold)) / Double(swipeThreshold) * 0.5)

                    if shouldShowStopButton {
                        Button(action: { onStop?() }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.accentColor.opacity(0.9))
                                .frame(height: 44)
                                .contentShape(Rectangle())
                        }
                    } else {
                        Menu {
                            Button(action: { showPhotoPicker = true }) {
                                Label("Photo", systemImage: "photo")
                            }

                            Button(action: startRecording) {
                                Label("Record", systemImage: "mic.fill")
                            }
                            .disabled(!canRecord)

                            Divider()

                            Menu {
                                Button(action: { setEffort(nil) }) {
                                    Label(conversationDefaultEffort?.displayName ?? "Default", systemImage: currentEffort == nil ? "checkmark" : "circle")
                                }
                                ForEach(EffortLevel.allCases, id: \.self) { level in
                                    Button(action: { setEffort(level) }) {
                                        Label(level.displayName, systemImage: currentEffort == level ? "checkmark" : "circle")
                                    }
                                }
                            } label: {
                                Label("Effort: \(currentEffort?.displayName ?? "Default")", systemImage: "brain.head.profile")
                            }
                        } label: {
                            ZStack {
                                Image(systemName: willQueue ? "clock.fill" : "paperplane.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(canSend ? .accentColor : .accentColor.opacity(0.4))
                                    .frame(height: 44)
                                    .contentShape(Rectangle())
                                    .animation(.easeInOut(duration: 0.2), value: willQueue)
                            }
                        } primaryAction: {
                            onSend()
                        }
                    }
                }
                .opacity((showInputBar && !isTranscribing) ? 1.0 - Double(min(swipeOffset, swipeThreshold)) / Double(swipeThreshold) * 0.7 : 0)
                .animation(.easeOut(duration: transitionDuration), value: showInputBar)
                .animation(.easeOut(duration: transitionDuration), value: isTranscribing)

                if showRecordingOverlay || isSwipingToRecord || isTranscribing {
                    RecordingOverlayView(
                        audioLevel: audioRecorder.audioLevel,
                        isTranscribing: isTranscribing,
                        onStop: stopRecording
                    )
                    .offset(y: (showRecordingOverlay || isTranscribing) ? 0 : max(0, swipeThreshold - swipeOffset))
                    .opacity((showRecordingOverlay || isTranscribing) ? 1 : Double(min(swipeOffset, swipeThreshold)) / Double(swipeThreshold))
                    .animation(.easeOut(duration: transitionDuration), value: showRecordingOverlay)
                    .animation(.easeOut(duration: transitionDuration), value: isTranscribing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .animation(.easeOut(duration: 0.15), value: filteredCommands.map(\.name))
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let verticalDrag = -value.translation.height
                    let horizontalDrag = -value.translation.width

                    if verticalDrag > abs(horizontalDrag) && canRecord && !audioRecorder.isRecording {
                        isSwipingToRecord = true
                        swipeOffset = verticalDrag
                        horizontalSwipeOffset = 0
                    } else if horizontalDrag > abs(verticalDrag) && !inputText.isEmpty {
                        horizontalSwipeOffset = horizontalDrag
                        swipeOffset = 0
                        isSwipingToRecord = false
                    }
                }
                .onEnded { value in
                    let verticalDrag = -value.translation.height
                    let horizontalDrag = -value.translation.width

                    if verticalDrag >= swipeThreshold && canRecord && isSwipingToRecord {
                        startRecording()
                    } else if horizontalDrag >= swipeThreshold && !inputText.isEmpty {
                        withAnimation(.easeOut(duration: 0.15)) {
                            inputText = ""
                            selectedImageData = nil
                        }
                    }

                    withAnimation(.easeOut(duration: 0.2)) {
                        swipeOffset = 0
                        horizontalSwipeOffset = 0
                        isSwipingToRecord = false
                    }
                }
        )
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
        .onChange(of: inputText) { old, new in
            if !old.isEmpty && new.isEmpty {
                placeholderIndex = Int.random(in: 0..<Self.placeholders.count)
                textFieldId = UUID()
            }
            if let query = atMentionQuery, query.count >= 1 {
                fileSearchDebounce?.cancel()
                fileSearchDebounce = Task {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    if !Task.isCancelled {
                        onFileSearch?(query)
                    }
                }
            }
        }
        .onReceive(Timer.publish(every: 8, on: .main, in: .common).autoconnect()) { _ in
            if inputText.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    placeholderIndex = (placeholderIndex + 1) % Self.placeholders.count
                }
            }
        }
        .onChange(of: inputText) { _, _ in
            idleTime = Date()
            showStopButton = false
        }
        .onChange(of: isInputFocused) { _, focused in
            if focused {
                showStopButton = false
            } else {
                idleTime = Date()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isRunning && !isInputFocused && Date().timeIntervalSince(idleTime) >= stopButtonDelay {
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

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImageData != nil
    }

    private var willQueue: Bool {
        isRunning && canSend
    }

    private var shouldShowStopButton: Bool {
        isRunning && showStopButton && !isInputFocused
    }

    private var canRecord: Bool {
        isConnected && isWhisperReady && !audioRecorder.isTranscribing
    }

    private func startRecording() {
        audioRecorder.requestPermission { granted in
            if granted {
                UIApplication.shared.isIdleTimerDisabled = true
                withAnimation(.easeOut(duration: transitionDuration)) {
                    showInputBar = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration) {
                    audioRecorder.startRecording()
                    withAnimation(.easeOut(duration: transitionDuration)) {
                        showRecordingOverlay = true
                    }
                }
            }
        }
    }

    private func stopRecording() {
        UIApplication.shared.isIdleTimerDisabled = false
        let data = audioRecorder.stopRecording()
        withAnimation(.easeOut(duration: transitionDuration)) {
            showRecordingOverlay = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration) {
            withAnimation(.easeOut(duration: transitionDuration)) {
                showInputBar = true
            }
            if let data = data {
                onTranscribe?(data)
            }
        }
    }

    private func resendPendingAudio() {
        if let data = audioRecorder.pendingAudioData() {
            onTranscribe?(data)
        }
    }

    private func selectFile(_ file: String) {
        guard let atIndex = inputText.lastIndex(of: "@") else { return }
        let fileName = file.lastPathComponent
        let beforeAt = String(inputText[..<atIndex])
        let afterQuery = inputText[inputText.index(after: atIndex)...]
        let spaceIndex = afterQuery.firstIndex(where: { $0 == " " || $0 == "\n" })
        let afterMention = spaceIndex.map { String(afterQuery[$0...]) } ?? ""
        inputText = beforeAt + "@" + fileName + afterMention
    }

    private func setEffort(_ level: EffortLevel?) {
        currentEffort = level
        onEffortChange?(level)
    }
}
