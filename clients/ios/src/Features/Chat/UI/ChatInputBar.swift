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
    @State private var images: [Data] = []
    @State private var pastedTexts: [String] = []
    @State private var bypassPasteDetection = false
    @State private var suggestions: [ChatInputSuggestion] = []
    @State private var fileSearchTask: Task<Void, Never>?
    @State private var recorder = ChatAudioRecorder()
    @State private var isTranscribing = false
    @State private var traceId = String(UUID().uuidString.prefix(6))
    @FocusState private var focused: Bool
    @Environment(\.appAccent) private var appAccent
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
        VStack(spacing: ThemeTokens.Spacing.xs) {
            if !suggestions.isEmpty {
                ChatInputBarSuggestions(suggestions: suggestions, onSelect: applySuggestion)
            }
            if !images.isEmpty || !pastedTexts.isEmpty {
                ChatInputBarAttachmentStrip(images: $images, pastedTexts: $pastedTexts) { text in
                    bypassPasteDetection = true
                    draft = draft.isEmpty ? text : draft + "\n" + text
                    focused = true
                }
            }
            if recorder.isRecording || isTranscribing {
                ChatInputBarRecordingOverlay(
                    level: recorder.level, isTranscribing: isTranscribing, onStop: stopRecording)
            } else {
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 0) {
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
                    if focused {
                        HStack(spacing: ThemeTokens.Spacing.m) {
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
                }
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
                .background(KeyboardDismissExemptArea())
            }
        }
        .padding(.horizontal, focused ? ThemeTokens.Spacing.m : ThemeTokens.Spacing.xl)
        .padding(.bottom, ThemeTokens.Spacing.s)
        .animation(.easeOut(duration: ThemeTokens.Duration.s), value: focused)
        .onAppear {
            AppLogger.uiInfo(
                "chatInput appear trace=\(traceId) session=\(sessionId.uuidString) enabled=\(enabled)"
            )
            draft = ChatDraftStore.text(for: sessionId)
            images = ChatDraftStore.images(for: sessionId)
            pastedTexts = ChatDraftStore.pastedTexts(for: sessionId)
        }
        .onDisappear {
            AppLogger.uiInfo("chatInput disappear trace=\(traceId) session=\(sessionId.uuidString)")
        }
        .onChange(of: draft) { oldValue, value in
            let bypass = bypassPasteDetection
            bypassPasteDetection = false
            if !bypass, let paste = ChatPasteDetector.extract(old: oldValue, new: value) {
                pastedTexts.append(paste.text)
                draft = paste.remaining
            } else {
                ChatDraftStore.setText(value, for: sessionId)
                recomputeSuggestions()
            }
        }
        .onChange(of: images) { _, value in
            ChatDraftStore.setImages(value, for: sessionId)
        }
        .onChange(of: pastedTexts) { _, value in
            ChatDraftStore.setPastedTexts(value, for: sessionId)
        }
        .onChange(of: focused) { oldValue, newValue in
            AppLogger.uiInfo(
                "chatInput focus trace=\(traceId) session=\(sessionId.uuidString) \(oldValue)->\(newValue)"
            )
        }
    }

    @ViewBuilder
    private var trailingButton: some View {
        if isStreaming && !canSend {
            Button {
                ChatService.abort(sessionId: sessionId, context: context)
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: ThemeTokens.Icon.xl, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, appAccent.color)
                    .frame(width: ThemeTokens.Icon.xl, height: ThemeTokens.Icon.xl)
                    .padding(.vertical, ThemeTokens.Spacing.s)
                    .padding(.trailing, ThemeTokens.Spacing.m)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        } else if canRecord {
            Image(systemName: "mic.fill")
                .appFont(size: ThemeTokens.Text.l, weight: .medium)
                .foregroundColor(appAccent.color)
                .padding(ThemeTokens.Spacing.m)
                .contentShape(Capsule())
                .gesture(recordGesture)
        } else {
            Menu {
                sendMenu
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: ThemeTokens.Icon.xl, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        canSend ? .white : Color.secondary,
                        canSend ? appAccent.color : Color.secondary.opacity(ThemeTokens.Opacity.s)
                    )
                    .frame(width: ThemeTokens.Icon.xl, height: ThemeTokens.Icon.xl)
                    .padding(.vertical, ThemeTokens.Spacing.s)
                    .padding(.trailing, ThemeTokens.Spacing.m)
                    .contentShape(Circle())
            } primaryAction: {
                send()
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
        }
    }

    @ViewBuilder
    private var sendMenu: some View {
        ChatInputBarModelMenu(sessionId: sessionId, model: model, effort: effort)
    }

    private func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if canSend && (!trimmed.isEmpty || !images.isEmpty || !pastedTexts.isEmpty) {
            let pendingImages = images
            let prompt = (pastedTexts + [trimmed]).filter { !$0.isEmpty }
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
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate<Session> { $0.id == sessionId })
            if let session = try? context.fetch(descriptor).first,
                let endpoint = session.endpoint, let path = session.path, !path.isEmpty,
                let files = await FilesService.search(
                    endpoint: endpoint, session: session, root: path, query: query)
            {
                if Task.isCancelled { return }
                if case .mention(let current) = ChatInputAutocomplete.trigger(in: draft),
                    current == query
                {
                    suggestions =
                        agents
                        + ChatInputAutocomplete.fileSuggestions(
                            files.filter { !$0.isDirectory }.map { $0.path })
                }
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

    private var recordGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                let up = -value.translation.height
                let isTap = abs(value.translation.width) < 10 && abs(value.translation.height) < 10
                let isSwipeUp = up >= 50 && up > abs(value.translation.width)
                if canRecord && (isTap || isSwipeUp) { startRecording() }
            }
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
                let descriptor = FetchDescriptor<Session>(
                    predicate: #Predicate<Session> { $0.id == sessionId })
                if let session = try? context.fetch(descriptor).first,
                    let endpoint = session.endpoint,
                    let text = await ChatTranscriptionService.transcribe(
                        endpoint: endpoint, sessionId: sessionId, audio: data),
                    !text.isEmpty
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
