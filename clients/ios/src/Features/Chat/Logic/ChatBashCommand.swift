import Foundation

enum ChatBashCommand {
    static func parse(_ command: String) -> (symbol: String, label: String)? {
        let firstLine = command.components(separatedBy: .newlines).first ?? command
        let parts = firstLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        if let head = parts.first, head == "git", let sub = gitSubcommand(after: Array(parts.dropFirst())) {
            return (gitSymbol(sub), "git \(sub)")
        }
        return nil
    }

    private static func gitSubcommand(after args: [String]) -> String? {
        var i = 0
        while i < args.count {
            let arg = args[i]
            if arg == "-c" || arg == "-C" || arg == "--git-dir" || arg == "--work-tree" {
                i += 2
                continue
            }
            if arg.hasPrefix("-") {
                i += 1
                continue
            }
            return arg
        }
        return nil
    }

    private static func gitSymbol(_ sub: String) -> String {
        switch sub {
        case "worktree": return "tree"
        case "status": return "info.circle"
        case "diff": return "plus.forwardslash.minus"
        case "log": return "clock.arrow.circlepath"
        case "commit": return "checkmark.seal"
        case "push": return "arrow.up"
        case "pull", "fetch": return "arrow.down"
        case "branch": return "arrow.triangle.branch"
        case "checkout", "switch": return "arrow.left.arrow.right"
        case "merge": return "arrow.triangle.merge"
        case "rebase": return "arrow.triangle.2.circlepath"
        case "stash": return "tray"
        case "add": return "plus.circle"
        case "rm": return "minus.circle"
        case "reset", "revert": return "arrow.uturn.backward"
        case "tag": return "tag"
        case "show": return "eye"
        case "blame": return "magnifyingglass"
        case "clone", "init": return "square.and.arrow.down"
        default: return "arrow.triangle.branch"
        }
    }
}
