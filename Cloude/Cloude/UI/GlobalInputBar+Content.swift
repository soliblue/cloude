import SwiftUI

extension GlobalInputBar {
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
                        withAnimation(.easeOut(duration: DS.Duration.quick)) {
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
                        withAnimation(.easeOut(duration: DS.Duration.quick)) {
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
                        audioRecorder: audioRecorder,
                        isTranscribing: isTranscribing,
                        onStop: stopRecording
                    )
                    .offset(y: (showRecordingOverlay || isTranscribing) ? 0 : max(0, Constants.swipeThreshold - swipeOffset))
                    .opacity((showRecordingOverlay || isTranscribing) ? 1 : Double(min(swipeOffset, Constants.swipeThreshold)) / Double(Constants.swipeThreshold))
                    .animation(.easeOut(duration: Constants.transitionDuration), value: showRecordingOverlay)
                    .animation(.easeOut(duration: Constants.transitionDuration), value: isTranscribing)
                }
            }
            .padding(.bottom, DS.Spacing.m)
        }
        .animation(.easeOut(duration: DS.Duration.quick), value: attachedImages.map(\.id))
        .animation(.easeOut(duration: DS.Duration.quick), value: attachedFiles.map(\.id))
        .overlay(alignment: .top) {
            suggestionsOverlay
                .alignmentGuide(.top) { d in d[.bottom] }
                .animation(.easeOut(duration: DS.Duration.quick), value: filteredCommands.map(\.name))
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
                    .shadow(color: .black.opacity(DS.Opacity.faint), radius: DS.Radius.s, y: -2)
            )
    }
}
