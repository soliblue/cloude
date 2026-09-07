import Foundation
import SwiftData

@MainActor enum ChatService {
    static var command: String?
    static var text = ""
    static var sessionId: UUID?
    static var accept = true

    static func send(
        session: Session, prompt: String, images: [Data], shellCommand: String?, context: ModelContext
    ) -> Bool {
        command = shellCommand
        text = prompt
        sessionId = session.id
        return accept
    }
}
