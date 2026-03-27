import SwiftUI

extension GlobalInputBar {
    var willQueue: Bool {
        isRunning && canSend
    }

    var shouldShowStopButton: Bool {
        isRunning && !isInputFocused && (showStopButton || !canSend)
    }

    var shouldShowRefreshButton: Bool {
        !isEnvironmentDisconnected && !isRunning && !canSend && onRefresh != nil
    }

    var actionButtonIcon: String {
        if isEnvironmentDisconnected { return "power" }
        if shouldShowStopButton { return "stop.fill" }
        if shouldShowRefreshButton { return "arrow.clockwise" }
        if willQueue { return "clock.fill" }
        return "paperplane.fill"
    }

    @ViewBuilder
    var actionButton: some View {
        if isEnvironmentDisconnected {
            Button(action: { onConnect?() }) {
                actionButtonLabel
            }
        } else if shouldShowRefreshButton {
            Menu {
                attachmentAndOptionsMenu
            } label: {
                actionButtonLabel
            } primaryAction: {
                refreshRotateTrigger += 1
                onRefresh?()
            }
        } else if shouldShowStopButton {
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
        Picker(selection: Binding(get: { currentEffort }, set: { setEffort($0) })) {
            Text(conversationDefaultEffort?.displayName ?? "Default").tag(EffortLevel?.none)
            ForEach(EffortLevel.allCases, id: \.self) { level in
                Text(level.displayName).tag(EffortLevel?.some(level))
            }
        } label: {
            Label("Effort: \(currentEffort?.displayName ?? "Default")", systemImage: "brain.head.profile")
        }
        Picker(selection: Binding(get: { currentModel }, set: { setModel($0) })) {
            Text("Auto").tag(ModelSelection?.none)
            ForEach(ModelSelection.allCases, id: \.self) { model in
                Text(model.displayName).tag(ModelSelection?.some(model))
            }
        } label: {
            Label("Model: \(currentModel?.displayName ?? "Auto")", systemImage: "cpu")
        }
    }

    var actionButtonLabel: some View {
        Image(systemName: actionButtonIcon)
            .symbolEffect(.rotate, value: refreshRotateTrigger)
            .symbolEffect(.bounce, value: sendBounceTrigger)
            .font(.system(size: DS.Icon.m, weight: .semibold))
            .foregroundColor(isEnvironmentDisconnected || canSend || shouldShowStopButton || shouldShowRefreshButton ? .white : .secondary.opacity(DS.Opacity.half))
            .frame(width: DS.Size.xl)
            .frame(maxHeight: .infinity)
            .background(isEnvironmentDisconnected || canSend || shouldShowStopButton || shouldShowRefreshButton ? Color.accentColor : Color.themeSecondary.opacity(DS.Opacity.half))
            .contentShape(Rectangle())
            .animation(.quickTransition, value: actionButtonIcon)
            .animation(.quickTransition, value: canSend)
    }

    func setEffort(_ level: EffortLevel?) {
        currentEffort = level
    }

    func setModel(_ model: ModelSelection?) {
        currentModel = model
    }
}
