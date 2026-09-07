import Foundation

nonisolated struct SessionWorktreeBranches: Codable {
    let branches: [SessionWorktreeBranch]
    let defaultBranch: String?
}
