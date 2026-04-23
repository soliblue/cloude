import SwiftData
import SwiftUI

struct ChatView: View {
    let session: Session
    @Binding var folderPickerRequest: SessionFolderPickerRequest?
    @Environment(\.modelContext) private var context
    @State private var barHeight: CGFloat = 0
    @Query private var messages: [ChatMessage]

    init(
        session: Session,
        folderPickerRequest: Binding<SessionFolderPickerRequest?> = .constant(nil)
    ) {
        self.session = session
        _folderPickerRequest = folderPickerRequest
        let sessionId = session.id
        _messages = Query(filter: #Predicate<ChatMessage> { $0.sessionId == sessionId })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if messages.isEmpty {
                SessionEmptyView(session: session, folderPickerRequest: $folderPickerRequest)
            } else {
                ChatViewMessageList(session: session, bottomInset: barHeight)
            }
            ChatInputBar(
                session: session,
                enabled: canSend,
                onSend: { prompt, images in
                    ChatService.send(session: session, prompt: prompt, images: images, context: context)
                }
            )
            .onGeometryChange(for: CGFloat.self) {
                $0.size.height
            } action: {
                barHeight = $0
            }
        }
        .onAppear {
            ChatService.resumeIfStuck(session: session, context: context)
        }
    }

    private var canSend: Bool {
        session.endpoint != nil && !(session.path ?? "").isEmpty
    }
}
