import Foundation

struct GitStatusSummary: Equatable {
    let branch: String
    let ahead: Int
    let behind: Int
    let additions: Int
    let deletions: Int
    let changeCount: Int

    init(status: GitStatus) {
        branch = status.branch
        ahead = status.ahead
        behind = status.behind
        additions = status.changes.compactMap(\.additions).reduce(0, +)
        deletions = status.changes.compactMap(\.deletions).reduce(0, +)
        changeCount = status.changes.count
    }

    var hasLineChanges: Bool {
        additions > 0 || deletions > 0
    }
}
