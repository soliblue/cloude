import Foundation
import SwiftData

@Model
final class GitStatus {
    @Attribute(.unique) var sessionId: UUID
    var branch: String = ""
    var ahead: Int = 0
    var behind: Int = 0
    var updatedAt: Date = Date.distantPast
    @Relationship(deleteRule: .cascade, inverse: \GitChange.status)
    var changes: [GitChange] = []

    init(sessionId: UUID, branch: String = "", ahead: Int = 0, behind: Int = 0) {
        self.sessionId = sessionId
        self.branch = branch
        self.ahead = ahead
        self.behind = behind
        self.updatedAt = .now
    }
}
