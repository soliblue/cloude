import Foundation

public struct GitFileStatus: Codable, Identifiable {
    public var id: String { path }
    public let status: String
    public let path: String

    public init(status: String, path: String) {
        self.status = status
        self.path = path
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

    public var isStaged: Bool {
        status.first?.isUppercase == true && status.first != "?"
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

    public var stagedCount: Int {
        files.filter { $0.isStaged }.count
    }

    public var unstagedCount: Int {
        files.count - stagedCount
    }
}
