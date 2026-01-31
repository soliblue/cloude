//
//  GlobalInputBar.swift
//  Cloude
//

import SwiftUI
import UIKit
import PhotosUI
import Combine

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

    var body: some View {
        ZStack {
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

                Button(action: toggleRecording) {
                    Image(systemName: micIcon)
                        .font(.system(size: 18))
                        .foregroundColor(micColor)
                }
                .disabled(!canRecord)

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
                        .foregroundColor(canSend ? .accentColor : .accentColor.opacity(0.4))
                }
                .disabled(!canSend && !hasClipboardContent)
            }
            .opacity(audioRecorder.isRecording ? 0.3 : 1.0)

            if audioRecorder.isRecording {
                RecordingOverlayView(
                    audioLevel: audioRecorder.audioLevel,
                    onStop: {
                        if let data = audioRecorder.stopRecording() {
                            onTranscribe?(data)
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: audioRecorder.isRecording)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

    private var actionButtonIcon: String {
        if inputText.isEmpty && !canSend {
            return "clipboard"
        }
        return "paperplane.fill"
    }

    private var micIcon: String {
        if audioRecorder.isTranscribing { return "ellipsis" }
        return audioRecorder.isRecording ? "stop.circle.fill" : "mic"
    }

    private var micColor: Color {
        if !canRecord { return .secondary.opacity(0.4) }
        return audioRecorder.isRecording ? .red : .accentColor
    }

    private func toggleRecording() {
        if audioRecorder.isRecording {
            if let data = audioRecorder.stopRecording() {
                onTranscribe?(data)
            }
        } else {
            audioRecorder.requestPermission { granted in
                if granted {
                    audioRecorder.startRecording()
                }
            }
        }
    }
}
