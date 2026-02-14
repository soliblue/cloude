import SwiftUI

extension GlobalInputBar {
    var willQueue: Bool {
        isRunning && canSend
    }

    var shouldShowStopButton: Bool {
        isRunning && showStopButton && !isInputFocused
    }

    var actionButtonIcon: String {
        if shouldShowStopButton { return "stop.fill" }
        if willQueue { return "clock.fill" }
        return "paperplane.fill"
    }

    @ViewBuilder
    var actionButton: some View {
        if shouldShowStopButton {
            Button(action: { onStop?() }) {
                actionButtonLabel
            }
        } else {
            Menu {
                Button(action: { showPhotoPicker = true }) {
                    Label("Photo", systemImage: "photo")
                }

                Button(action: { showFilePicker = true }) {
                    Label("File", systemImage: "doc")
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

                Menu {
                    Button(action: { setModel(nil) }) {
                        Label("Auto", systemImage: currentModel == nil ? "checkmark" : "circle")
                    }
                    ForEach(ModelSelection.allCases, id: \.self) { model in
                        Button(action: { setModel(model) }) {
                            Label(model.displayName, systemImage: currentModel == model ? "checkmark" : "circle")
                        }
                    }
                } label: {
                    Label("Model: \(currentModel?.displayName ?? "Auto")", systemImage: "cpu")
                }
            } label: {
                actionButtonLabel
            } primaryAction: {
                onSend()
            }
        }
    }

    var actionButtonLabel: some View {
        Image(systemName: actionButtonIcon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(canSend || shouldShowStopButton ? .white : .accentColor.opacity(0.4))
            .frame(width: 36, height: 36)
            .background(canSend || shouldShowStopButton ? Color.accentColor : Color.clear)
            .clipShape(Circle())
            .contentShape(Circle().inset(by: -8))
            .animation(.easeInOut(duration: 0.2), value: actionButtonIcon)
            .animation(.easeInOut(duration: 0.2), value: canSend)
    }

    func setEffort(_ level: EffortLevel?) {
        currentEffort = level
    }

    func setModel(_ model: ModelSelection?) {
        currentModel = model
    }
}
