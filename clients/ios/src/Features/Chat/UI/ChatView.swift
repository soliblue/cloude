import SwiftData
import SwiftUI

struct ChatView: View {
    let session: Session
    @Binding var folderPickerRequest: SessionFolderPickerRequest?
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme
    @State private var traceId = String(UUID().uuidString.prefix(6))

    init(
        session: Session,
        folderPickerRequest: Binding<SessionFolderPickerRequest?> = .constant(nil)
    ) {
        self.session = session
        _folderPickerRequest = folderPickerRequest
    }

    var body: some View {
        #if DEBUG
        let _ = PerfCounters.enabled ? Self._logChanges() : ()
        #endif
        let _ = PerfCounters.bump("cv.body")
        ChatViewBody(session: session, folderPickerRequest: $folderPickerRequest)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: ThemeTokens.Spacing.s) {
                    ChatGoalStatusRow(session: session)
                    if session.followsRemote { ChatRemoteStatusRow(session: session) }
                    if let notice = ChatInteractionStore.shared.agentRequests[session.id]?.first {
                        ChatAgentAttentionRow(session: session, notice: notice).id(notice.id)
                    }
                    if let request = ChatInteractionStore.shared.requests[session.id]?.first {
                        ChatInteractionCard(session: session, request: request)
                            .id(request.id)
                    }
                    ChatInputBar(
                        sessionId: session.id,
                        isStreaming: session.isStreaming,
                        provider: session.provider,
                        model: session.model,
                        effort: session.effort,
                        permissionMode: session.permissionMode,
                        contextTokens: session.contextTokens,
                        contextWindow: session.contextWindow,
                        enabled: canSend
                    )
                    .equatable()
                }
                .background(theme.palette.background)
            }
            .onAppear {
                AppLogger.uiInfo(
                    "chatView appear trace=\(traceId) session=\(session.id.uuidString) configured=\(session.isConfigured)"
                )
                ChatService.resumeIfStuck(session: session, context: context)
            }
            .task(
                id:
                    "\(session.connectionKey)|\(session.providerRaw ?? "")"
            ) {
                if let endpoint = session.endpoint, let path = session.path, !path.isEmpty,
                    let manifest = await SessionManifestService.fetch(
                        endpoint: endpoint, sessionId: session.id, path: path, provider: session.provider),
                    !Task.isCancelled
                {
                    SessionManifestStore.shared.set(
                        skills: manifest.skills, agents: manifest.agents,
                        transcription: manifest.transcription ?? false, for: session.id)
                }
            }
            .task(
                id:
                    "requests|\(session.connectionKey)|\(session.providerRaw ?? "")|\(session.followsRemote)|\(scenePhase)|\(ChatInteractionStore.shared.agentRequests[session.id]?.isEmpty == false)"
            ) {
                if scenePhase == .active { await ChatInteractionService.observe(session: session) }
            }
            .task(id: "remote|\(session.connectionKey)|\(session.followsRemote)|\(scenePhase)") {
                while session.followsRemote && scenePhase == .active && !Task.isCancelled {
                    await SessionRemoteFollowService.refresh(session: session, context: context)
                    try? await Task.sleep(for: .seconds(5))
                }
            }
            .task(id: "goal|\(session.connectionKey)|\(session.isStreaming)") {
                if !session.isStreaming { _ = await ChatGoalService.refresh(session: session) }
            }
            .onDisappear {
                AppLogger.uiInfo("chatView disappear trace=\(traceId) session=\(session.id.uuidString)")
            }
            .onChange(of: scenePhase) { _, phase in
                AppLogger.uiInfo(
                    "chatView scene trace=\(traceId) session=\(session.id.uuidString) phase=\(String(describing: phase))"
                )
                if phase == .active {
                    ChatService.resumeIfStuck(session: session, context: context)
                }
            }
    }

    private var canSend: Bool {
        session.endpoint != nil && !(session.path ?? "").isEmpty && !session.remoteIsRunning
    }
}

private struct ChatViewBody: View {
    let session: Session
    @Binding var folderPickerRequest: SessionFolderPickerRequest?
    @State private var traceId = String(UUID().uuidString.prefix(6))

    init(
        session: Session,
        folderPickerRequest: Binding<SessionFolderPickerRequest?>
    ) {
        self.session = session
        _folderPickerRequest = folderPickerRequest
    }

    var body: some View {
        #if DEBUG
        let _ = PerfCounters.enabled ? Self._logChanges() : ()
        #endif
        let _ = PerfCounters.bump("cvb.body")
        ChatViewMessageList(session: session, folderPickerRequest: $folderPickerRequest)
            .onAppear {
                AppLogger.uiInfo(
                    "chatBody appear trace=\(traceId) session=\(session.id.uuidString)"
                )
            }
            .onDisappear {
                AppLogger.uiInfo("chatBody disappear trace=\(traceId) session=\(session.id.uuidString)")
            }
    }
}
