import Foundation
import SwiftData

@Model
final class ChatGitChange {
    @Attribute(.unique) var id: UUID = UUID()
    var messageId: UUID = UUID()
    var sessionId: UUID = UUID()
    var path: String = ""
    var typeRaw: String = GitChangeType.modified.rawValue
    var additions: Int = 0
    var deletions: Int = 0

    init(
        messageId: UUID,
        sessionId: UUID,
        path: String,
        type: GitChangeType,
        additions: Int,
        deletions: Int
    ) {
        self.id = UUID()
        self.messageId = messageId
        self.sessionId = sessionId
        self.path = path
        self.typeRaw = type.rawValue
        self.additions = additions
        self.deletions = deletions
    }

    var type: GitChangeType { GitChangeType(rawValue: typeRaw) ?? .modified }
}
