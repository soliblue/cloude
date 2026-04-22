import Foundation

enum GitChangeType: String, Codable {
    case added
    case modified
    case deleted
    case renamed
    case copied
    case untracked
    case ignored
    case conflicted
}
