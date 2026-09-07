import Foundation
import SwiftData

@main
struct GitHistoryTests {
    static func check(_ condition: Bool) { precondition(condition) }

    @MainActor
    static func main() throws {
        let container = try ModelContainer(for: GitCommit.self, GitStatus.self, GitChange.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let sessionId = UUID()
        let otherId = UUID()
        let all = (0..<120).map { GitCommitDTO(sha: String(format: "%040d", $0), subject: "Commit \($0)", author: "Fixture", date: "2026-09-06T12:00:00Z") }
        GitActions.replaceLog(sessionId: sessionId, commits: Array(all.prefix(50)), context: context)
        GitActions.replaceLog(sessionId: otherId, commits: Array(all.prefix(1)), context: context)
        try context.save()
        let descriptor = FetchDescriptor<GitCommit>(predicate: #Predicate { $0.sessionId == sessionId }, sortBy: [SortDescriptor(\.order)])
        let initialID = try context.fetch(descriptor)[0].persistentModelID
        GitActions.replaceLog(sessionId: sessionId, commits: Array(all[45..<100]), context: context, append: true)
        check(try context.fetch(descriptor).count == 100)
        GitActions.replaceLog(sessionId: sessionId, commits: Array(all[100...]), context: context, append: true)
        check(try context.fetch(descriptor).count == 120)
        GitActions.replaceLog(sessionId: sessionId, commits: Array(all.prefix(50)), context: context)
        check(try context.fetch(descriptor).count == 120)
        check(try context.fetch(descriptor)[0].persistentModelID == initialID)
        let newHead = GitCommitDTO(sha: String(repeating: "f", count: 40), subject: "New head", author: "Fixture", date: "2026-09-06T13:00:00Z")
        GitActions.replaceLog(sessionId: sessionId, commits: [newHead] + Array(all.prefix(49)), context: context)
        let refreshed = try context.fetch(descriptor)
        precondition(refreshed.count == 121)
        precondition(refreshed[1].persistentModelID == initialID)
        precondition(refreshed.enumerated().allSatisfy { $0.offset == $0.element.order })
        GitActions.replaceLog(sessionId: sessionId, commits: [newHead], context: context)
        check(try context.fetch(descriptor).count == 1)
        let other = FetchDescriptor<GitCommit>(predicate: #Predicate { $0.sessionId == otherId })
        check(try context.fetch(other).count == 1)
        print("PASS: history pagination, duplicate overlap, stable identities, new head retains older pages, branch reset and session isolation")
    }
}
