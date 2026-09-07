import Foundation

nonisolated enum ChatReviewKind: String, Codable, CaseIterable, Identifiable {
    case uncommittedChanges, baseBranch, commit, custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .uncommittedChanges: "Uncommitted changes"
        case .baseBranch: "Compare with a branch"
        case .commit: "Specific commit"
        case .custom: "Custom instructions"
        }
    }
}
