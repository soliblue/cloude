import SwiftUI

extension ConversationInputBar {
    var willQueue: Bool {
        isRunning && canSend
    }

    var canShowStopButton: Bool {
        isRunning && !isInputFocused && (isShowingStopButton || !canSend)
    }

    var canShowRefreshButton: Bool {
        !isEnvironmentDisconnected && !isRunning && !canSend && onRefresh != nil
    }

    var actionButtonIcon: String {
        if isEnvironmentDisconnected { return "power" }
        if canShowStopButton { return "stop.fill" }
        if canShowRefreshButton { return "arrow.clockwise" }
        if willQueue { return "clock.fill" }
        return "paperplane.fill"
    }

    @ViewBuilder
    var actionButton: some View {
        if isEnvironmentDisconnected {
            Button(action: { onConnect?() }) {
                actionButtonLabel
            }
        } else if canShowRefreshButton {
            Menu {
                attachmentAndOptionsMenu
            } label: {
                actionButtonLabel
            } primaryAction: {
                refreshRotateTrigger += 1
                onRefresh?()
            }
        } else if canShowStopButton {
            Button(action: { onStop?() }) {
                actionButtonLabel
            }
        } else {
            Menu {
                attachmentAndOptionsMenu
            } label: {
                actionButtonLabel
            } primaryAction: {
                if canSend {
                    sendBounceTrigger += 1
                    onSend()
                }
            }
            .disabled(environmentMismatch)
        }
    }

    @ViewBuilder
    var attachmentAndOptionsMenu: some View {
        Button(action: { isShowingPhotoPicker = true }) {
            Label("Photo", systemImage: "photo")
        }
        .agenticID("chat_add_photo_button")
        Button(action: { isShowingFilePicker = true }) {
            Label("File", systemImage: "doc")
        }
        .agenticID("chat_add_file_button")
        Button(action: startRecording) {
            Label("Record", systemImage: "mic.fill")
        }
        .agenticID("chat_record_button")
        .disabled(!canRecord)
        Divider()
        Menu {
            Button(action: { currentEffort = nil }) {
                Label("Default", systemImage: currentEffort == nil ? "checkmark" : "")
            }
            ForEach(EffortLevel.allCases, id: \.self) { level in
                Button(action: { currentEffort = level }) {
                    Label(
                        level.displayName,
                        systemImage: currentEffort == level ? "checkmark" : ""
                    )
                }
            }
        } label: {
            Label("Effort: \(currentEffort?.displayName ?? "Default")", systemImage: "brain.head.profile")
        }
        .agenticID("chat_effort_picker")
        Menu {
            Button(action: { currentModel = nil }) {
                Label("Auto", systemImage: currentModel == nil ? "checkmark" : "")
            }
            ForEach(ModelSelection.allCases, id: \.self) { model in
                Button(action: { currentModel = model }) {
                    Label(
                        model.displayName,
                        systemImage: currentModel == model ? "checkmark" : ""
                    )
                }
            }
        } label: {
            Label("Model: \(currentModel?.displayName ?? "Auto")", systemImage: "cpu")
        }
        .agenticID("chat_model_picker")
    }

    var actionButtonLabel: some View {
        Image(systemName: actionButtonIcon)
            .symbolEffect(.rotate, value: refreshRotateTrigger)
            .symbolEffect(.bounce, value: sendBounceTrigger)
            .font(.system(size: DS.Icon.m, weight: .semibold))
            .foregroundColor(isEnvironmentDisconnected || canSend || canShowStopButton || canShowRefreshButton ? .white : .secondary.opacity(DS.Opacity.m))
            .frame(width: DS.Size.l)
            .frame(maxHeight: .infinity)
            .background(isEnvironmentDisconnected || canSend || canShowStopButton || canShowRefreshButton ? Color.accentColor : Color.themeSecondary.opacity(DS.Opacity.m))
            .contentShape(Rectangle())
            .animation(.quickTransition, value: actionButtonIcon)
            .animation(.quickTransition, value: canSend)
    }

}
