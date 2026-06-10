import SwiftData
import SwiftUI

struct ChatView: View {
    let session: Session
    @Binding var folderPickerRequest: SessionFolderPickerRequest?
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
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
                ChatInputBar(
                    sessionId: session.id,
                    isStreaming: session.isStreaming,
                    model: session.model,
                    effort: session.effort,
                    contextTokens: session.contextTokens,
                    contextWindow: session.contextWindow,
                    enabled: canSend
                )
                .equatable()
            }
            .onAppear {
                AppLogger.uiInfo(
                    "chatView appear trace=\(traceId) session=\(session.id.uuidString) configured=\(session.isConfigured)"
                )
                ChatService.resumeIfStuck(session: session, context: context)
            }
            .task(id: session.id) {
                if let endpoint = session.endpoint, let path = session.path, !path.isEmpty,
                    let manifest = await SessionManifestService.fetch(
                        endpoint: endpoint, sessionId: session.id, path: path)
                {
                    SessionManifestStore.shared.set(
                        skills: manifest.skills, agents: manifest.agents,
                        transcription: manifest.transcription ?? false, for: session.id)
                }
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
        session.endpoint != nil && !(session.path ?? "").isEmpty
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
