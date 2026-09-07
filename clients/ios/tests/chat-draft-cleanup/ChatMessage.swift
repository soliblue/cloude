import Foundation
import SwiftData

@Model final class ChatMessage {
    var sessionId: UUID
    init(sessionId: UUID) { self.sessionId = sessionId }
}
