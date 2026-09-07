import Foundation
import SwiftData

@MainActor enum ChatService {
    static var accept = true
    static var count = 0
    static var prompt = ""
    static var permissions: ChatPermissionMode?
    static var onSend: (() -> Void)?

    static func send(session: Session, prompt: String, images: [Data], context: ModelContext) -> Bool {
        precondition(images.isEmpty)
        count += 1
        self.prompt = prompt
        permissions = session.permissionMode
        onSend?()
        if accept { SessionActions.setStreaming(true, for: session) }
        return accept
    }
}
