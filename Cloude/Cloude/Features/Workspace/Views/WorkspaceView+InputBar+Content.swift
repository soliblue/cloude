import SwiftUI

extension WorkspaceInputBar {
    var inputBarOpacity: Double {
        if !showInputBar || isTranscribing {
            return 0
        }
        return clampedSwipeProgress.map { 1.0 - $0 * DS.Opacity.l } ?? 1
    }

    var recordingOverlayOpacity: Double {
        if showRecordingOverlay || isTranscribing {
            return 1
        }
        return clampedSwipeProgress ?? 0
    }

    var recordingOverlayOffset: CGFloat {
        if showRecordingOverlay || isTranscribing {
            return 0
        }
        return max(0, Constants.swipeThreshold - sanitizedSwipeOffset)
    }

    var contentStack: some View {
        VStack(spacing: 0) {
            if audioRecorder.hasPendingAudio && !audioRecorder.isRecording && !isTranscribing {
                PendingAudioBanner(
                    onResend: resendPendingAudio,
                    onDiscard: { audioRecorder.clearPendingAudio() }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if !attachedImages.isEmpty {
                ImageAttachmentStrip(
                    images: attachedImages,
                    onRemove: { id in
                        withAnimation(.easeOut(duration: DS.Duration.s)) {
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
                        withAnimation(.easeOut(duration: DS.Duration.s)) {
                            attachedFiles.removeAll { $0.id == id }
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            ZStack(alignment: .bottom) {
                inputRow
                    .opacity(inputBarOpacity)
                    .animation(.easeOut(duration: Constants.transitionDuration), value: showInputBar)
                    .animation(.easeOut(duration: Constants.transitionDuration), value: isTranscribing)

                if showRecordingOverlay || isSwipingToRecord || isTranscribing {
                    RecordingOverlayView(
                        audioRecorder: audioRecorder,
                        isTranscribing: isTranscribing,
                        onStop: stopRecording
                    )
                    .offset(y: recordingOverlayOffset)
                    .opacity(recordingOverlayOpacity)
                    .animation(.easeOut(duration: Constants.transitionDuration), value: showRecordingOverlay)
                    .animation(.easeOut(duration: Constants.transitionDuration), value: isTranscribing)
                }
            }
            .padding(.bottom, DS.Spacing.m)
        }
        .animation(.easeOut(duration: DS.Duration.s), value: attachedImages.map(\.id))
        .animation(.easeOut(duration: DS.Duration.s), value: attachedFiles.map(\.id))
        .overlay(alignment: .top) {
            suggestionsOverlay
                .alignmentGuide(.top) { d in d[.bottom] }
                .animation(.easeOut(duration: DS.Duration.s), value: filteredCommands.map(\.name))
        }
    }

    @ViewBuilder
    private var suggestionsOverlay: some View {
        if showFileSuggestions {
            suggestionBackdrop {
                FileSuggestionsList(
                    files: fileSearchResults,
                    onSelect: selectFile
                )
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if showCommandSuggestions {
            suggestionBackdrop {
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
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if !historySuggestions.isEmpty {
            suggestionBackdrop {
                HistorySuggestions(
                    suggestions: historySuggestions,
                    onSelect: { text in
                        inputText = text
                        isInputFocused = false
                        onSend()
                    }
                )
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func suggestionBackdrop<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                Color.themeBackground
                    .shadow(color: .black.opacity(DS.Opacity.s), radius: DS.Radius.s, y: -2)
            )
    }

    private var sanitizedSwipeOffset: CGFloat {
        swipeOffset.isFinite ? max(0, swipeOffset) : 0
    }

    private var clampedSwipeProgress: Double? {
        if Constants.swipeThreshold > 0 {
            return min(max(Double(sanitizedSwipeOffset / Constants.swipeThreshold), 0), 1)
        }
        return nil
    }
}
