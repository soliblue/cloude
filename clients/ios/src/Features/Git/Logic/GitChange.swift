import Foundation
import SwiftData

@Model
final class GitChange {
    var path: String = ""
    var typeRaw: String = GitChangeType.modified.rawValue
    var isStaged: Bool = false
    var additions: Int? = nil
    var deletions: Int? = nil
    var status: GitStatus?

    init(
        path: String,
        type: GitChangeType,
        isStaged: Bool,
        additions: Int? = nil,
        deletions: Int? = nil
    ) {
        self.path = path
        self.typeRaw = type.rawValue
        self.isStaged = isStaged
        self.additions = additions
        self.deletions = deletions
    }

    var type: GitChangeType {
        get { GitChangeType(rawValue: typeRaw) ?? .modified }
        set { typeRaw = newValue.rawValue }
    }
}
