import Foundation
import SwiftData

@Model
final class ChatHistoryTurnRecord {
    @Attribute(.unique) var id: String
    var sessionId: UUID
    var turnId: String
    var order: Int64
    var status: String

    init(sessionId: UUID, turnId: String, order: Int64, status: String) {
        self.id = sessionId.uuidString + ":" + turnId
        self.sessionId = sessionId
        self.turnId = turnId
        self.order = order
        self.status = status
    }
}
