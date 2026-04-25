import SwiftData
import SwiftUI

struct ChatInputBar: View, Equatable {
    let sessionId: UUID
    let isStreaming: Bool
    let model: ChatModel?
    let effort: ChatEffort?
    let endpoint: Endpoint?
    let path: String?
    var enabled: Bool = true
    @State private var draft: String = ""
    @State private var images: [Data] = []
    @State private var skills: [Skill] = []
    @State private var agents: [Agent] = []
    @State private var traceId = String(UUID().uuidString.prefix(6))
    @FocusState private var focused: Bool
    @Environment(\.appAccent) private var appAccent
    @Environment(\.modelContext) private var context

    static func == (lhs: ChatInputBar, rhs: ChatInputBar) -> Bool {
        lhs.sessionId == rhs.sessionId
            && lhs.isStreaming == rhs.isStreaming
            && lhs.model == rhs.model
            && lhs.effort == rhs.effort
            && lhs.enabled == rhs.enabled
            && lhs.endpoint?.id == rhs.endpoint?.id
            && lhs.path == rhs.path
    }

    init(
        sessionId: UUID,
        isStreaming: Bool,
        model: ChatModel?,
        effort: ChatEffort?,
        endpoint: Endpoint?,
        path: String?,
        enabled: Bool = true
    ) {
        self.sessionId = sessionId
        self.isStreaming = isStreaming
        self.model = model
        self.effort = effort
        self.endpoint = endpoint
        self.path = path
        self.enabled = enabled
        PerfCounters.bumpInit("ib")
    }

    var body: some View {
        #if DEBUG
        let _ = Self._logChanges()
        #endif
        let _ = PerfCounters.bump("ib.body")
        VStack(spacing: ThemeTokens.Spacing.xs) {
            if let mode = pickerMode {
                ChatInputBarAutocompletePicker(
                    mode: mode,
                    skills: skills,
                    agents: agents,
                    onSelectSkill: { name in insertOrReplace(trigger: "/", name: name) },
                    onSelectAgent: { name in insertOrReplace(trigger: "@", name: name) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if !images.isEmpty {
                ChatInputBarAttachmentStrip(images: $images)
            }
            HStack(alignment: .bottom, spacing: ThemeTokens.Spacing.s) {
                ChatInputBarAttachmentPicker(images: $images)
                TextField("Message", text: $draft, axis: .vertical)
                    .appFont(size: ThemeTokens.Text.m)
                    .lineLimit(1...6)
                    .focused($focused)
                    .padding(.horizontal, ThemeTokens.Spacing.m)
                    .padding(.vertical, ThemeTokens.Spacing.m)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
                if isStreaming {
                    Button {
                        ChatService.abort(sessionId: sessionId, context: context)
                    } label: {
                        Text(Image(systemName: "stop.fill"))
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                            .foregroundColor(appAccent.color)
                            .padding(ThemeTokens.Spacing.m)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Capsule())
                } else {
                    Menu {
                        sendMenu
                    } label: {
                        Text(Image(systemName: "paperplane.fill"))
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                            .foregroundColor(canSend ? appAccent.color : .secondary)
                            .padding(ThemeTokens.Spacing.m)
                            .contentShape(Capsule())
                    } primaryAction: {
                        send()
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .disabled(!enabled)
                }
            }
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.bottom, ThemeTokens.Spacing.s)
        .animation(.easeInOut(duration: ThemeTokens.Duration.s), value: pickerMode)
        .task(id: sessionId) {
            if let endpoint, let path, !path.isEmpty {
                if skills.isEmpty,
                    let fetched = await SessionService.skills(endpoint: endpoint, sessionId: sessionId, path: path)
                {
                    skills = fetched
                }
                if agents.isEmpty,
                    let fetched = await SessionService.agents(endpoint: endpoint, sessionId: sessionId, path: path)
                {
                    agents = fetched
                }
            }
        }
        .onAppear {
            AppLogger.uiInfo(
                "chatInput appear trace=\(traceId) session=\(sessionId.uuidString) enabled=\(enabled)"
            )
        }
        .onDisappear {
            AppLogger.uiInfo("chatInput disappear trace=\(traceId) session=\(sessionId.uuidString)")
        }
        .onChange(of: focused) { oldValue, newValue in
            AppLogger.uiInfo(
                "chatInput focus trace=\(traceId) session=\(sessionId.uuidString) \(oldValue)->\(newValue)"
            )
        }
    }

    private var pickerMode: ChatInputBarAutocompletePicker.Mode? {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if let q = activeQuery(for: "/") { return .skills(query: q) }
        if let q = activeQuery(for: "@") { return .agents(query: q) }
        if trimmed.isEmpty, path?.isEmpty == false, !(skills.isEmpty && agents.isEmpty) {
            return .ambient
        }
        return nil
    }

    private func activeQuery(for trigger: Character) -> String? {
        guard let idx = draft.lastIndex(of: trigger) else { return nil }
        let after = draft[draft.index(after: idx)...]
        if after.contains(where: { $0 == " " || $0 == "\n" }) { return nil }
        if idx != draft.startIndex {
            let prev = draft[draft.index(before: idx)]
            if !prev.isWhitespace { return nil }
        }
        return String(after).lowercased()
    }

    private func insertOrReplace(trigger: Character, name: String) {
        let replacement = "\(trigger)\(name) "
        if let idx = draft.lastIndex(of: trigger) {
            let before = draft[..<idx]
            let after = draft[draft.index(after: idx)...]
            if !after.contains(where: { $0 == " " || $0 == "\n" }),
                idx == draft.startIndex || draft[draft.index(before: idx)].isWhitespace
            {
                draft = String(before) + replacement
                return
            }
        }
        if !draft.isEmpty && !draft.hasSuffix(" ") { draft += " " }
        draft += replacement
    }

    @ViewBuilder
    private var sendMenu: some View {
        Menu {
            Button {
                SessionActions.setModel(nil, for: sessionId, context: context)
            } label: {
                Label("Auto", systemImage: model == nil ? "checkmark" : "")
            }
            ForEach(ChatModel.allCases, id: \.self) { model in
                Button {
                    SessionActions.setModel(model, for: sessionId, context: context)
                } label: {
                    Label(model.displayName, systemImage: self.model == model ? "checkmark" : "")
                }
            }
        } label: {
            Label("Model: \(model?.displayName ?? "Auto")", systemImage: "cpu")
        }
        Menu {
            Button {
                SessionActions.setEffort(nil, for: sessionId, context: context)
            } label: {
                Label("Default", systemImage: effort == nil ? "checkmark" : "")
            }
            ForEach(ChatEffort.allCases, id: \.self) { level in
                Button {
                    SessionActions.setEffort(level, for: sessionId, context: context)
                } label: {
                    Label(level.displayName, systemImage: effort == level ? "checkmark" : "")
                }
            }
        } label: {
            Label("Effort: \(effort?.displayName ?? "Default")", systemImage: "brain.head.profile")
        }
    }

    private func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if canSend && (!trimmed.isEmpty || !images.isEmpty) {
            ChatService.send(sessionId: sessionId, prompt: trimmed, images: images, context: context)
            draft = ""
            images = []
            focused = false
        }
    }

    private var canSend: Bool {
        enabled && (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty)
    }
}
