import Foundation
import SwiftData

@Model
final class ChatMessage {
    enum Role: String { case user, assistant }
    enum State: String { case streaming, complete, failed }

    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var roleRaw: String
    var text: String
    var stateRaw: String
    var imagesData: [Data]
    var createdAt: Date
    var costUsd: Double? = nil
    @Relationship(deleteRule: .cascade, inverse: \ChatToolCall.message)
    var toolCalls: [ChatToolCall] = []

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        role: Role,
        text: String = "",
        images: [Data] = [],
        state: State = .complete
    ) {
        self.id = id
        self.sessionId = sessionId
        self.roleRaw = role.rawValue
        self.text = text
        self.stateRaw = state.rawValue
        self.imagesData = images
        self.createdAt = .now
    }

    var role: Role { Role(rawValue: roleRaw) ?? .assistant }
    var state: State {
        get { State(rawValue: stateRaw) ?? .complete }
        set { stateRaw = newValue.rawValue }
    }
    var orderedToolCalls: [ChatToolCall] {
        toolCalls.sorted { $0.order < $1.order }
    }
}
