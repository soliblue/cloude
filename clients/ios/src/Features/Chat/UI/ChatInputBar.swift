import SwiftData
import SwiftUI

struct ChatInputBar: View, Equatable {
    let sessionId: UUID
    let isStreaming: Bool
    let provider: ChatProvider
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
    @State private var voice = ChatVoiceStore()
    @State private var isOnScreen = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var traceId = String(UUID().uuidString.prefix(6))
    @State private var focused = false
    @Environment(\.appAccent) private var appAccent
    @Environment(\.modelContext) private var context

    static func == (lhs: ChatInputBar, rhs: ChatInputBar) -> Bool {
        lhs.sessionId == rhs.sessionId
            && lhs.isStreaming == rhs.isStreaming
            && lhs.provider == rhs.provider
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
        provider: ChatProvider = .claude,
        model: ChatModel?,
        effort: ChatEffort?,
        permissionMode: ChatPermissionMode = .bypassPermissions,
        contextTokens: Int = 0,
        contextWindow: Int = 0,
        enabled: Bool = true
    ) {
        self.sessionId = sessionId
        self.isStreaming = isStreaming
        self.provider = provider
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
            if recorder.isRecording || voice.isTranscribing {
                ChatInputBarRecordingOverlay(
                    level: recorder.level, isTranscribing: voice.isTranscribing, onStop: stopRecording)
            } else {
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 0) {
                        if !focused {
                            ChatInputBarAttachmentPicker(sessionId: sessionId, images: $images)
                        }
                        LiteralTextField(
                            title: "Message", text: $draft,
                            focused: Binding(get: { focused }, set: { focused = $0 }),
                            lines: 1...6, fontSize: ThemeTokens.Text.m
                        )
                        .padding(.horizontal, ThemeTokens.Spacing.m)
                        .padding(.vertical, ThemeTokens.Spacing.m)
                        if !focused {
                            trailingButton
                        }
                    }
                    if focused {
                        HStack(spacing: 0) {
                            ChatInputBarAttachmentPicker(sessionId: sessionId, images: $images)
                            ChatInputBarMetaRow(
                                sessionId: sessionId,
                                provider: provider,
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
            isOnScreen = true
            voice.isVisible = scenePhase == .active
            AppLogger.uiInfo(
                "chatInput appear trace=\(traceId) session=\(sessionId.uuidString) enabled=\(enabled)"
            )
            if draft != ChatDraftStore.text(for: sessionId) {
                bypassPasteDetection = true
                draft = ChatDraftStore.text(for: sessionId)
            }
            images = ChatDraftStore.images(for: sessionId)
            pastedTexts = ChatDraftStore.pastedTexts(for: sessionId)
        }
        .task(id: sessionId) {
            let initialText = draft
            let initialImages = images
            let initialPastes = pastedTexts
            await ChatDraftService.load(sessionId)
            if !Task.isCancelled {
                if draft == initialText && draft != ChatDraftStore.text(for: sessionId) {
                    bypassPasteDetection = true
                    draft = ChatDraftStore.text(for: sessionId)
                }
                if images == initialImages { images = ChatDraftStore.images(for: sessionId) }
                if pastedTexts == initialPastes { pastedTexts = ChatDraftStore.pastedTexts(for: sessionId) }
            }
        }
        .onDisappear {
            AppLogger.uiInfo("chatInput disappear trace=\(traceId) session=\(sessionId.uuidString)")
            isOnScreen = false
            ChatVoiceService.cancel(recorder: recorder, store: voice, onError: presentInputError)
            ChatDraftService.flushForBackground()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                voice.isVisible = isOnScreen
            } else if phase == .background {
                ChatVoiceService.cancel(recorder: recorder, store: voice, onError: presentInputError)
            }
        }
        .onChange(of: draft) { oldValue, value in
            let bypass = bypassPasteDetection
            bypassPasteDetection = false
            if !bypass, let paste = ChatPasteDetector.extract(old: oldValue, new: value) {
                pastedTexts.append(paste.text)
                draft = paste.remaining
            } else {
                ChatDraftService.setText(value, for: sessionId)
                recomputeSuggestions()
            }
        }
        .onChange(of: images) { _, value in
            ChatDraftService.setImages(value, for: sessionId)
        }
        .onChange(of: pastedTexts) { _, value in
            ChatDraftService.setPastedTexts(value, for: sessionId)
        }
        .onChange(of: focused) { oldValue, newValue in
            AppLogger.uiInfo(
                "chatInput focus trace=\(traceId) session=\(sessionId.uuidString) \(oldValue)->\(newValue)"
            )
        }
    }

    @ViewBuilder
    private var trailingButton: some View {
        if isStreaming && canSend { stopButton }
        if isStreaming && !canSend {
            stopButton
        } else if canRecord {
            Image(systemName: "mic.fill")
                .appFont(size: ThemeTokens.Text.l, weight: .medium)
                .foregroundColor(appAccent.color)
                .frame(width: ThemeTokens.Icon.xl, height: ThemeTokens.Icon.xl)
                .padding(.vertical, ThemeTokens.Spacing.s)
                .padding(.horizontal, ThemeTokens.Spacing.m)
                .contentShape(Circle())
                .gesture(recordGesture)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Record voice instruction")
                .accessibilityAction { startRecording() }
        } else {
            Menu {
                sendMenu
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: ThemeTokens.Icon.xl, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        canSend ? .white : ThemeColor.secondary,
                        canSend ? appAccent.color : ThemeColor.secondary.opacity(ThemeTokens.Opacity.s)
                    )
                    .frame(width: ThemeTokens.Icon.xl, height: ThemeTokens.Icon.xl)
                    .padding(.vertical, ThemeTokens.Spacing.s)
                    .padding(.horizontal, ThemeTokens.Spacing.m)
                    .contentShape(Circle())
            } primaryAction: {
                send()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isStreaming ? "Queue message for agent" : "Send message to agent")
            .accessibilityHint("Double tap to send. Open the menu to choose model and reasoning effort.")
            .disabled(!enabled)
        }
    }

    private var stopButton: some View {
        Button {
            ChatService.abort(sessionId: sessionId, context: context)
        } label: {
            Image(systemName: "stop.circle.fill")
                .font(.system(size: ThemeTokens.Icon.xl, weight: .bold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, appAccent.color)
                .frame(width: ThemeTokens.Icon.xl, height: ThemeTokens.Icon.xl)
                .padding(.vertical, ThemeTokens.Spacing.s)
                .padding(.horizontal, ThemeTokens.Spacing.m)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop active agent turn")
    }

    @ViewBuilder
    private var sendMenu: some View {
        ChatInputBarModelMenu(sessionId: sessionId, provider: provider, model: model, effort: effort)
    }

    private func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if canSend && (!trimmed.isEmpty || !images.isEmpty || !pastedTexts.isEmpty) {
            let pendingImages = images
            let prompt = (pastedTexts + [trimmed]).filter { !$0.isEmpty }
                .joined(separator: "\n\n")
            if ChatService.send(
                sessionId: sessionId, prompt: prompt, images: pendingImages,
                references: ChatDraftStore.references(for: sessionId).filter {
                    prompt.contains($0.path) || prompt.contains("/" + $0.name)
                }, context: context)
            {
                focused = false
                draft = ""
                images = []
                pastedTexts = []
                suggestions = []
                ChatDraftService.clear(sessionId)
            }
        }
    }

    private func applySuggestion(_ suggestion: ChatInputSuggestion) {
        if provider == .codex {
            if suggestion.kind == .skill,
                let skill = SessionManifestStore.shared.skills(for: sessionId).first(where: {
                    $0.name == suggestion.title
                }), let path = skill.path
            {
                ChatDraftService.addReference(
                    ChatReference(name: skill.name, path: path, kind: "skill"), for: sessionId)
            }
            if suggestion.kind == .file {
                ChatDraftService.addReference(
                    ChatReference(
                        name: suggestion.title,
                        path: suggestion.insertText.trimmingCharacters(in: .whitespacesAndNewlines), kind: "mention"),
                    for: sessionId)
            }
        }
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
            && (SessionManifestStore.shared.transcriptionReady(for: sessionId) || ChatLocalTranscription.available)
            && !recorder.isRecording && !voice.isTranscribing && !voice.isRequestingPermission
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
        ChatVoiceService.start(recorder: recorder, store: voice, onError: presentInputError)
    }

    private func stopRecording() {
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionId })
        ChatVoiceService.stop(
            recorder: recorder, store: voice, session: try? context.fetch(descriptor).first,
            onText: { text in
                let combined = draft.isEmpty ? text : draft + " " + text
                ChatDraftService.setText(combined, for: sessionId)
                bypassPasteDetection = true
                draft = combined
            }, onError: presentInputError)
    }

    private func presentInputError(_ title: String, _ message: String) {
        SessionToastStore.shared.present(
            SessionToast(
                sessionId: sessionId, title: title, symbol: "exclamationmark.triangle.fill",
                snippet: message))
    }
}
