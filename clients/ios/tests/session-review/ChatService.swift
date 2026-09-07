import Foundation
import SwiftData

@MainActor enum ChatService {
    static var sent: ChatReviewTarget?
    static var text = ""
    static var sessionId: UUID?
    static var accept = true
    static func send(
        session: Session, prompt: String, images: [Data], reviewTarget: ChatReviewTarget?, context: ModelContext
    ) -> Bool {
        sent = reviewTarget
        text = prompt
        sessionId = session.id
        return accept
    }
}
