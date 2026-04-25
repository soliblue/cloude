import SwiftData
import SwiftUI

struct ChatView: View {
    let session: Session
    @Binding var folderPickerRequest: SessionFolderPickerRequest?
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    init(
        session: Session,
        folderPickerRequest: Binding<SessionFolderPickerRequest?> = .constant(nil)
    ) {
        self.session = session
        _folderPickerRequest = folderPickerRequest
    }

    var body: some View {
        let _ = PerfCounters.bump("cv.body")
        ChatViewBody(session: session, folderPickerRequest: $folderPickerRequest)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ChatInputBar(
                    session: session,
                    enabled: canSend,
                    onSend: { prompt, images in
                        ChatService.send(
                            session: session, prompt: prompt, images: images, context: context)
                    }
                )
            }
            .onAppear {
                ChatService.resumeIfStuck(session: session, context: context)
            }
            .onChange(of: scenePhase) { _, phase in
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
    @Query private var messages: [ChatMessage]

    init(
        session: Session,
        folderPickerRequest: Binding<SessionFolderPickerRequest?>
    ) {
        self.session = session
        _folderPickerRequest = folderPickerRequest
        let sessionId = session.id
        _messages = Query(filter: #Predicate<ChatMessage> { $0.sessionId == sessionId })
    }

    var body: some View {
        let _ = PerfCounters.bump("cvb.body")
        if messages.isEmpty {
            SessionEmptyView(session: session, folderPickerRequest: $folderPickerRequest)
        } else {
            ChatViewMessageList(session: session)
        }
    }
}
