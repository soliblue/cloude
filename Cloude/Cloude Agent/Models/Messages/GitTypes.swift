//
//  GitTypes.swift
//  Cloude Agent
//

import Foundation

struct GitFileStatus: Codable, Identifiable {
    var id: String { path }
    let status: String
    let path: String

    var statusDescription: String {
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

    var isStaged: Bool {
        status.first?.isUppercase == true && status.first != "?"
    }
}

struct GitStatusInfo: Codable {
    let branch: String
    let ahead: Int
    let behind: Int
    let files: [GitFileStatus]

    var hasChanges: Bool {
        !files.isEmpty
    }

    var stagedCount: Int {
        files.filter { $0.isStaged }.count
    }

    var unstagedCount: Int {
        files.count - stagedCount
    }
}
