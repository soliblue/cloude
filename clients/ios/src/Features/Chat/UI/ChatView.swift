import SwiftData
import SwiftUI

struct ChatView: View {
    let session: Session
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: 0) {
            ChatViewMessageList(sessionId: session.id)
            ChatInputBar(onSend: { prompt, images in
                ChatService.send(session: session, prompt: prompt, images: images, context: context)
            })
        }
    }
}
