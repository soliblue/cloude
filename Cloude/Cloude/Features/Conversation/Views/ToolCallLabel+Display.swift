// ToolCallLabel+Display.swift

import SwiftUI
import CloudeShared

extension ToolCallLabel {
    func bashDisplayDetail(_ cmd: String) -> String {
        let parsed = BashCommandParser.parse(cmd)
        switch parsed.command {
        case "ls":                          return pathDetail(parsed, fallback: ".")
        case "cd":                          return pathDetail(parsed, fallback: "~")
        case "mkdir", "rm", "find":         return pathDetail(parsed, fallback: parsed.command == "find" ? "." : "")
        case "git", "claude":               return parsed.allArgs.first.map { midTruncate($0, maxLength: 10) } ?? ""
        case "npm", "yarn", "pnpm", "bun",
             "cargo", "pip", "pip3",
             "swift", "docker", "kubectl":  return parsed.allArgs.first ?? ""
        case "make":                        return parsed.firstArg ?? "all"
        case "python", "python3", "node":   return fileDetail(parsed)
        case "cat", "head", "tail":         return parsed.firstArg.map { truncateFilename($0.lastPathComponent, maxLength: 8) } ?? ""
        case "source":                      return parsed.firstArg.map { truncateFilename($0.lastPathComponent, maxLength: 8) } ?? ""
        case "xcodebuild":                  return parsed.flagValue("-scheme") ?? parsed.subcommand ?? "build"
        case "fastlane":                    return parsed.allArgs.prefix(2).joined(separator: " ")
        case "cp", "mv":                    return moveDetail(parsed)
        case "chmod":                       return chmodDetail(parsed)
        case "curl", "wget":               return parsed.firstArg.map { truncateURL($0, maxLength: 10) } ?? ""
        case "grep", "rg":                 return parsed.firstArg.map { truncateText($0, maxLength: 8) } ?? ""
        case "echo":                        return truncateText(parsed.allArgs.joined(separator: " "), maxLength: 9)
        case "export":                      return parsed.firstArg.map { $0.split(separator: "=").first.map(String.init) ?? $0 } ?? ""
        default:                            return ""
        }
    }

    private func pathDetail(_ parsed: BashCommandParser, fallback: String) -> String {
        parsed.firstArg.map { truncatePath($0, maxLength: 9) } ?? fallback
    }

    private func fileDetail(_ parsed: BashCommandParser) -> String {
        parsed.firstArg.map { truncateFilename($0, maxLength: 8) } ?? ""
    }

    private func moveDetail(_ parsed: BashCommandParser) -> String {
        let args = parsed.allArgs
        if args.count >= 2, let last = args.last { return "→ \(truncatePath(last, maxLength: 7))" }
        return args.first.map { truncatePath($0, maxLength: 9) } ?? ""
    }

    private func chmodDetail(_ parsed: BashCommandParser) -> String {
        let args = parsed.allArgs
        guard args.count >= 2 else { return "" }
        return "\(args[0]) \(truncatePath(args[1], maxLength: 6))"
    }

    var iconName: String {
        if let action = iosAction { return ToolCallLabel.iosIcons[action] ?? "iphone" }
        if ToolCallLabel.isWhiteboardTool(name) { return "rectangle.on.rectangle.angled" }
        switch name {
        case "Bash":
            if isScript { return "scroll" }
            return bashIconName(input ?? "")
        case "Read": return "doc.text"
        case "Write": return "doc.badge.plus"
        case "Edit": return "pencil.line"
        case "Glob": return "folder.magnifyingglass"
        case "Grep": return "magnifyingglass"
        case "Task": return "person.2"
        case "WebFetch": return "globe"
        case "WebSearch": return "magnifyingglass.circle"
        case "TodoWrite": return "checklist"
        case "AskUserQuestion": return "questionmark.bubble"
        case "NotebookEdit": return "text.book.closed"
        case "Skill": return "command"
        case "TeamCreate": return "person.3.fill"
        case "TeamDelete": return "person.3.fill"
        case "SendMessage": return "paperplane.fill"
        case "Agent": return agentIconName
        default:
            if WidgetRegistry.isWidget(name) { return WidgetRegistry.iconName(name) }
            return "gear"
        }
    }

    private func bashIconName(_ cmd: String) -> String {
        let parsed = BashCommandParser.parse(cmd)

        if let sub = parsed.subcommand {
            switch parsed.command {
            case "git":
                return gitSubcommandIcons[sub] ?? "arrow.triangle.branch"
            case "npm", "yarn", "pnpm", "bun":
                return npmSubcommandIcons[sub] ?? "shippingbox"
            case "cargo":
                return cargoSubcommandIcons[sub] ?? "gearshape.2"
            case "pip", "pip3":
                return pipSubcommandIcons[sub] ?? "cube"
            case "swift":
                return swiftSubcommandIcons[sub] ?? "swift"
            case "docker":
                return dockerSubcommandIcons[sub] ?? "shippingbox"
            case "kubectl":
                return kubectlSubcommandIcons[sub] ?? "server.rack"
            default:
                break
            }
        }

        return bashIconMap[parsed.command] ?? "terminal"
    }
}
