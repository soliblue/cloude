import Foundation
import SwiftData

@Model
final class GitCommit {
    @Attribute(.unique) var id: UUID
    var sessionId: UUID
    var sha: String = ""
    var subject: String = ""
    var author: String = ""
    var date: Date = Date.distantPast
    var order: Int = 0

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        sha: String,
        subject: String,
        author: String,
        date: Date,
        order: Int
    ) {
        self.id = id
        self.sessionId = sessionId
        self.sha = sha
        self.subject = subject
        self.author = author
        self.date = date
        self.order = order
    }
}
