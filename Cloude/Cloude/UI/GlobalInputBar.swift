//
//  GlobalInputBar.swift
//  Cloude
//

import SwiftUI
import UIKit
import PhotosUI
import Combine

struct SlashCommand {
    let name: String
    let description: String
    let icon: String
}

private let slashCommands: [SlashCommand] = [
    SlashCommand(name: "compact", description: "Compress conversation context", icon: "arrow.triangle.2.circlepath"),
    SlashCommand(name: "context", description: "Show token usage", icon: "chart.pie"),
    SlashCommand(name: "cost", description: "Show usage stats", icon: "dollarsign.circle"),
]

struct GlobalInputBar: View {
    @Binding var inputText: String
    @Binding var selectedImageData: Data?
    let hasClipboardContent: Bool
    let isConnected: Bool
    let isWhisperReady: Bool
    let onSend: () -> Void
    var onTranscribe: ((Data) -> Void)?

    @State private var selectedItem: PhotosPickerItem?
    @FocusState private var isInputFocused: Bool
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var placeholderIndex = Int.random(in: 0..<20)
    @State private var textFieldId = UUID()
    @State private var swipeOffset: CGFloat = 0
    @State private var isSwipingToRecord = false
    @State private var showInputBar = true
    @State private var showRecordingOverlay = false

    private let swipeThreshold: CGFloat = 60
    private let transitionDuration: Double = 0.15

    private static let placeholders = [
        "fix the login bug pls",
        "why isn't the button showing",
        "make the font bigger",
        "add a back button here",
        "this crashes on launch",
        "deploy to testflight",
        "push to git",
        "can you add dark mode",
        "the animation is janky",
        "why is this so slow",
        "add a loading spinner",
        "make it look nicer",
        "refactor this mess",
        "write tests for this",
        "explain what this does",
        "add error handling pls",
        "the padding looks off",
        "can we cache this",
        "hide the keyboard on tap",
        "make it work offline"
    ]

    private var placeholder: String {
        Self.placeholders[placeholderIndex % Self.placeholders.count]
    }

    private var filteredCommands: [SlashCommand] {
        guard inputText.hasPrefix("/") else { return [] }
        let query = String(inputText.dropFirst()).lowercased()
        if query.isEmpty {
            return slashCommands
        }
        return slashCommands.filter { $0.name.lowercased().hasPrefix(query) }
    }

    private var isSlashCommand: Bool {
        inputText.hasPrefix("/")
    }

    var body: some View {
        VStack(spacing: 0) {
            if !filteredCommands.isEmpty {
                SlashCommandSuggestions(
                    commands: filteredCommands,
                    onSelect: { command in
                        inputText = "/\(command.name)"
                        onSend()
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
                                    .font(.system(size: 16))
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

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundColor(.accentColor)
                }

                Button(action: {
                    if inputText.isEmpty && hasClipboardContent {
                        if let text = UIPasteboard.general.string {
                            inputText = text
                        }
                    } else {
                        onSend()
                    }
                }) {
                    Image(systemName: actionButtonIcon)
                        .font(.system(size: 18))
                        .foregroundColor((canSend || showPasteButton) ? .accentColor : .accentColor.opacity(0.4))
                }
                .disabled(!canSend && !showPasteButton)
            }
            .opacity(showInputBar ? 1.0 - Double(min(swipeOffset, swipeThreshold)) / Double(swipeThreshold) * 0.7 : 0)
            .animation(.easeOut(duration: transitionDuration), value: showInputBar)

                if showRecordingOverlay || isSwipingToRecord {
                    RecordingOverlayView(
                        audioLevel: audioRecorder.audioLevel,
                        onStop: stopRecording
                    )
                    .offset(y: showRecordingOverlay ? 0 : max(0, swipeThreshold - swipeOffset))
                    .opacity(showRecordingOverlay ? 1 : Double(min(swipeOffset, swipeThreshold)) / Double(swipeThreshold))
                    .animation(.easeOut(duration: transitionDuration), value: showRecordingOverlay)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .animation(.easeOut(duration: 0.15), value: filteredCommands.map(\.name))
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard canRecord && !audioRecorder.isRecording else { return }
                    let verticalDrag = -value.translation.height
                    if verticalDrag > 0 {
                        isSwipingToRecord = true
                        swipeOffset = verticalDrag
                    }
                }
                .onEnded { value in
                    let verticalDrag = -value.translation.height
                    if verticalDrag >= swipeThreshold && canRecord {
                        startRecording()
                    }
                    withAnimation(.easeOut(duration: 0.2)) {
                        swipeOffset = 0
                        isSwipingToRecord = false
                    }
                }
        )
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
        }
        .onReceive(Timer.publish(every: 8, on: .main, in: .common).autoconnect()) { _ in
            if inputText.isEmpty {
                withAnimation(.easeInOut(duration: 0.3)) {
                    placeholderIndex = (placeholderIndex + 1) % Self.placeholders.count
                }
            }
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImageData != nil
    }

    private var canRecord: Bool {
        isConnected && isWhisperReady && !audioRecorder.isTranscribing
    }

    private var showPasteButton: Bool {
        inputText.isEmpty && !canSend
    }

    private var actionButtonIcon: String {
        showPasteButton ? "clipboard" : "paperplane.fill"
    }

    private func startRecording() {
        audioRecorder.requestPermission { granted in
            if granted {
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
}

struct SlashCommandSuggestions: View {
    let commands: [SlashCommand]
    let onSelect: (SlashCommand) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(commands, id: \.name) { command in
                    Button(action: { onSelect(command) }) {
                        HStack(spacing: 6) {
                            Image(systemName: command.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text("/\(command.name)")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.cyan.opacity(0.12))
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
