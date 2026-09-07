import Foundation
import SwiftData

@Model
final class ChatMessage {
    enum Role: String { case user, assistant }
    enum State: String { case streaming, complete, failed, retrying, queued }

    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var roleRaw: String
    var text: String
    var stateRaw: String
    var imagesData: [Data]
    var imageSources: [String]? = nil
    var createdAt: Date
    var costUsd: Double? = nil
    var model: String? = nil
    var hasToolCalls: Bool = false
    var remoteItemId: String? = nil
    var planIsComplete: Bool? = nil
    var planEventSeq: Int? = nil
    var referencesData: Data? = nil
    var reviewTargetData: Data? = nil
    var shellCommand: String? = nil
    var thinking: String = ""
    var thinkingMs: Int = 0
    var thinkingRedacted: Bool = false

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        role: Role,
        text: String = "",
        images: [Data] = [],
        state: State = .complete,
        references: [ChatReference] = [],
        reviewTarget: ChatReviewTarget? = nil,
        shellCommand: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.roleRaw = role.rawValue
        self.text = text
        self.stateRaw = state.rawValue
        self.imagesData = images
        self.createdAt = .now
        self.referencesData = references.isEmpty ? nil : try? JSONEncoder().encode(references)
        self.reviewTargetData = reviewTarget.flatMap { try? JSONEncoder().encode($0) }
        self.shellCommand = shellCommand
    }

    var reviewTarget: ChatReviewTarget? {
        reviewTargetData.flatMap { try? JSONDecoder().decode(ChatReviewTarget.self, from: $0) }
    }

    var references: [ChatReference] {
        referencesData.flatMap { try? JSONDecoder().decode([ChatReference].self, from: $0) } ?? []
    }

    var role: Role { Role(rawValue: roleRaw) ?? .assistant }
    var state: State {
        get { State(rawValue: stateRaw) ?? .complete }
        set { stateRaw = newValue.rawValue }
    }
    var hasThinking: Bool { thinkingMs > 0 || !thinking.isEmpty || thinkingRedacted }
}
