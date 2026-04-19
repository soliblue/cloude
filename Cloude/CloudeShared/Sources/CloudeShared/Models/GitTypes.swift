import Foundation

public struct GitFileStatus: Codable, Identifiable {
    public var id: String { path + (staged ? "-staged" : "-unstaged") }
    public let status: String
    public let path: String
    public let staged: Bool
    public var additions: Int?
    public var deletions: Int?

    public init(status: String, path: String, staged: Bool = false, additions: Int? = nil, deletions: Int? = nil) {
        self.status = status
        self.path = path
        self.staged = staged
        self.additions = additions
        self.deletions = deletions
    }

    public var statusDescription: String {
        switch status {
        case "M": return "Modified"
        case "A": return "Added"
        case "D": return "Deleted"
        case "R": return "Renamed"
        case "C": return "Copied"
        case "U": return "Unmerged"
        case "??": return "Untracked"
        case "!!": return "Ignored"
        default: return status
        }
    }

}

public struct GitStatusInfo: Codable {
    public let branch: String
    public let ahead: Int
    public let behind: Int
    public let files: [GitFileStatus]

    public init(branch: String, ahead: Int, behind: Int, files: [GitFileStatus]) {
        self.branch = branch
        self.ahead = ahead
        self.behind = behind
        self.files = files
    }

    public var hasChanges: Bool {
        !files.isEmpty
    }

    public var stagedFiles: [GitFileStatus] {
        files.filter { $0.staged }
    }

    public var unstagedFiles: [GitFileStatus] {
        files.filter { !$0.staged }
    }
}
