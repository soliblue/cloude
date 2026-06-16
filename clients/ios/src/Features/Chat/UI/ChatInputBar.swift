import SwiftData
import SwiftUI

struct ChatInputBar: View, Equatable {
    let sessionId: UUID
    let isStreaming: Bool
    let model: ChatModel?
    let effort: ChatEffort?
    let permissionMode: ChatPermissionMode
    let contextTokens: Int
    let contextWindow: Int
    var enabled: Bool = true
    @State private var draft: String = ""
    @State private var images: [ChatImageAttachment] = []
    @State private var pastedTexts: [ChatPastedTextAttachment] = []
    @State private var bypassPasteDetection = false
    @State private var suggestions: [ChatInputSuggestion] = []
    @State private var fileSearchTask: Task<Void, Never>?
    @State private var recorder = ChatAudioRecorder()
    @State private var isTranscribing = false
    @State private var traceId = String(UUID().uuidString.prefix(6))
    @FocusState private var focused: Bool
    @Environment(\.modelContext) private var context

    static func == (lhs: ChatInputBar, rhs: ChatInputBar) -> Bool {
        lhs.sessionId == rhs.sessionId
            && lhs.isStreaming == rhs.isStreaming
            && lhs.model == rhs.model
            && lhs.effort == rhs.effort
            && lhs.permissionMode == rhs.permissionMode
            && lhs.contextTokens == rhs.contextTokens
            && lhs.contextWindow == rhs.contextWindow
            && lhs.enabled == rhs.enabled
    }

    init(
        sessionId: UUID,
        isStreaming: Bool,
        model: ChatModel?,
        effort: ChatEffort?,
        permissionMode: ChatPermissionMode = .bypassPermissions,
        contextTokens: Int = 0,
        contextWindow: Int = 0,
        enabled: Bool = true
    ) {
        self.sessionId = sessionId
        self.isStreaming = isStreaming
        self.model = model
        self.effort = effort
        self.permissionMode = permissionMode
        self.contextTokens = contextTokens
        self.contextWindow = contextWindow
        self.enabled = enabled
        PerfCounters.bumpInit("ib")
    }

    var body: some View {
        #if DEBUG
        let _ = PerfCounters.enabled ? Self._logChanges() : ()
        #endif
        let _ = PerfCounters.bump("ib.body")
        content
            .padding(.horizontal, focused ? ThemeTokens.Spacing.m : ThemeTokens.Spacing.xl)
            .padding(.bottom, ThemeTokens.Spacing.s)
            .animation(.easeOut(duration: ThemeTokens.Duration.s), value: focused)
            .onAppear(perform: appear)
            .onDisappear(perform: disappear)
            .onChange(of: draft) { oldValue, value in
                draftChanged(oldValue: oldValue, value: value)
            }
            .onChange(of: images) { _, value in
                ChatDraftStore.setImages(value.map(\.data), for: sessionId)
            }
            .onChange(of: pastedTexts) { _, value in
                ChatDraftStore.setPastedTexts(value.map(\.text), for: sessionId)
            }
            .onChange(of: focused) { oldValue, newValue in
                AppLogger.uiInfo(
                    "chatInput focus trace=\(traceId) session=\(sessionId.uuidString) \(oldValue)->\(newValue)"
                )
            }
    }

    private var content: some View {
        VStack(spacing: ThemeTokens.Spacing.xs) {
            suggestionsContent
            attachmentsContent
            inputContent
        }
    }
    @ViewBuilder
    private var suggestionsContent: some View {
        if !suggestions.isEmpty {
            ChatInputBarSuggestions(suggestions: suggestions, onSelect: applySuggestion)
        }
    }
    @ViewBuilder
    private var attachmentsContent: some View {
        if !images.isEmpty || !pastedTexts.isEmpty {
            ChatInputBarAttachmentStrip(images: $images, pastedTexts: $pastedTexts) { text in
                bypassPasteDetection = true
                draft = draft.isEmpty ? text : draft + "\n" + text
                focused = true
            }
        }
    }
    @ViewBuilder
    private var inputContent: some View {
        if recorder.isRecording || isTranscribing {
            ChatInputBarRecordingOverlay(
                level: recorder.level, isTranscribing: isTranscribing, onStop: stopRecording)
        } else {
            inputSurface
        }
    }
    private var inputSurface: some View {
        VStack(spacing: 0) {
            compactInputRow
            if focused {
                expandedInputRow
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
        .background(KeyboardDismissExemptArea())
    }
    private var compactInputRow: some View {
        HStack(alignment: .center, spacing: 0) {
            if !focused {
                ChatInputBarAttachmentPicker(images: $images)
            }
            TextField("Message", text: $draft, axis: .vertical)
                .appFont(size: ThemeTokens.Text.m)
                .lineLimit(1...6)
                .focused($focused)
                .padding(.horizontal, ThemeTokens.Spacing.m)
                .padding(.vertical, ThemeTokens.Spacing.m)
            if !focused {
                trailingButton
            }
        }
    }
    private var expandedInputRow: some View {
        HStack(spacing: 0) {
            ChatInputBarAttachmentPicker(images: $images)
            ChatInputBarMetaRow(
                sessionId: sessionId,
                model: model,
                effort: effort,
                permissionMode: permissionMode,
                contextTokens: contextTokens,
                contextWindow: contextWindow
            )
            trailingButton
        }
        .padding(.leading, ThemeTokens.Spacing.xs)
        .padding(.bottom, ThemeTokens.Spacing.xs)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    private var trailingButton: some View {
        ChatInputBarTrailingButton(
            sessionId: sessionId,
            isStreaming: isStreaming,
            canSend: canSend,
            canRecord: canRecord,
            enabled: enabled,
            model: model,
            effort: effort,
            onAbort: abort,
            onSend: send,
            onStartRecording: startRecording
        )
    }
    private func appear() {
        AppLogger.uiInfo(
            "chatInput appear trace=\(traceId) session=\(sessionId.uuidString) enabled=\(enabled)"
        )
        draft = ChatDraftStore.text(for: sessionId)
        images = ChatDraftStore.images(for: sessionId).map { ChatImageAttachment(data: $0) }
        pastedTexts = ChatDraftStore.pastedTexts(for: sessionId).map {
            ChatPastedTextAttachment(text: $0)
        }
    }
    private func disappear() {
        AppLogger.uiInfo("chatInput disappear trace=\(traceId) session=\(sessionId.uuidString)")
    }
    private func draftChanged(oldValue: String, value: String) {
        let bypass = bypassPasteDetection
        bypassPasteDetection = false
        if !bypass, let paste = ChatPasteDetector.extract(old: oldValue, new: value) {
            pastedTexts.append(ChatPastedTextAttachment(text: paste.text))
            draft = paste.remaining
        } else {
            ChatDraftStore.setText(value, for: sessionId)
            recomputeSuggestions()
        }
    }

    private func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if canSend && (!trimmed.isEmpty || !images.isEmpty || !pastedTexts.isEmpty) {
            let pendingImages = images.map(\.data)
            let prompt = (pastedTexts.map(\.text) + [trimmed]).filter { !$0.isEmpty }
                .joined(separator: "\n\n")
            focused = false
            draft = ""
            images = []
            pastedTexts = []
            suggestions = []
            ChatDraftStore.setText("", for: sessionId)
            ChatDraftStore.setImages([], for: sessionId)
            ChatDraftStore.setPastedTexts([], for: sessionId)
            ChatService.send(
                sessionId: sessionId, prompt: prompt, images: pendingImages, context: context)
        }
    }

    private func applySuggestion(_ suggestion: ChatInputSuggestion) {
        draft = ChatInputAutocomplete.apply(suggestion, to: draft)
        suggestions = []
        focused = true
    }

    private func recomputeSuggestions() {
        fileSearchTask?.cancel()
        switch ChatInputAutocomplete.trigger(in: draft) {
        case .slash(let query):
            suggestions = ChatInputAutocomplete.skillSuggestions(
                SessionManifestStore.shared.skills(for: sessionId), query: query)
        case .mention(let query):
            let agents = ChatInputAutocomplete.agentSuggestions(
                SessionManifestStore.shared.agents(for: sessionId), query: query)
            suggestions = agents
            scheduleFileSearch(query: query, agents: agents)
        case .none:
            suggestions = []
        }
    }

    private func scheduleFileSearch(query: String, agents: [ChatInputSuggestion]) {
        if query.isEmpty { return }
        fileSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return }
            let fileSuggestions = await ChatInputSuggestionService.fileSuggestions(
                sessionId: sessionId, query: query, context: context)
            if Task.isCancelled { return }
            if case .mention(let current) = ChatInputAutocomplete.trigger(in: draft),
                current == query
            {
                suggestions = agents + fileSuggestions
            }
        }
    }

    private var canSend: Bool {
        enabled
            && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty
                || !pastedTexts.isEmpty)
    }

    private var canRecord: Bool {
        enabled && draft.isEmpty && images.isEmpty && pastedTexts.isEmpty
            && SessionManifestStore.shared.transcriptionReady(for: sessionId)
            && !recorder.isRecording && !isTranscribing
    }

    private func abort() {
        ChatService.abort(sessionId: sessionId, context: context)
    }

    private func startRecording() {
        Task {
            if await recorder.requestPermission() {
                recorder.start()
            }
        }
    }

    private func stopRecording() {
        if let data = recorder.stop(), !data.isEmpty {
            isTranscribing = true
            Task {
                if let text = await ChatInputTranscriptionService.transcribe(
                    sessionId: sessionId, audio: data, context: context)
                {
                    bypassPasteDetection = true
                    draft = draft.isEmpty ? text : draft + " " + text
                }
                isTranscribing = false
            }
        } else {
            isTranscribing = false
        }
    }
}
