import Foundation

enum ChatToolKind: Equatable, Sendable {
    case bash
    case read
    case write
    case edit
    case glob
    case grep
    case web
    case todo
    case task
    case other

    init(name: String) {
        switch name {
        case "Bash": self = .bash
        case "Read": self = .read
        case "Write": self = .write
        case "Edit", "MultiEdit": self = .edit
        case "Glob": self = .glob
        case "Grep": self = .grep
        case "WebFetch", "WebSearch": self = .web
        case "TodoWrite": self = .todo
        case "Task": self = .task
        default: self = .other
        }
    }

    var symbol: String {
        switch self {
        case .bash: return "terminal"
        case .read: return "doc.text"
        case .write: return "square.and.pencil"
        case .edit: return "pencil"
        case .glob: return "folder.badge.questionmark"
        case .grep: return "text.magnifyingglass"
        case .web: return "globe"
        case .todo: return "checklist"
        case .task: return "sparkles"
        case .other: return "hammer"
        }
    }
}
