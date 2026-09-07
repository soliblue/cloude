import Foundation

nonisolated enum ChatToolKind: Equatable, Sendable {
    case bash
    case read
    case write
    case edit
    case glob
    case grep
    case web
    case todo
    case task
    case skill
    case image
    case other

    init(name: String) {
        switch name {
        case "Bash", "commandExecution", "exec_command", "shell_command": self = .bash
        case "Read": self = .read
        case "Write": self = .write
        case "Edit", "MultiEdit", "fileChange", "apply_patch": self = .edit
        case "Glob": self = .glob
        case "Grep": self = .grep
        case "WebFetch", "WebSearch", "webSearch", "web.run": self = .web
        case "TodoWrite", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "update_plan": self = .todo
        case "Task", "Agent", "collabAgentToolCall", "subAgentActivity", "spawn_agent": self = .task
        case "Skill": self = .skill
        case "imageGeneration", "ImageGeneration": self = .image
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
        case .task: return "brain"
        case .skill: return "command"
        case .image: return "photo"
        case .other: return "hammer"
        }
    }
}
