import SwiftUI

struct ToolCallLabel: View {
    let name: String
    let input: String?
    var size: Size = .regular

    enum Size {
        case regular
        case small

        var iconSize: CGFloat { self == .regular ? 15 : 14 }
        var textSize: CGFloat { self == .regular ? 13 : 12 }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: size.iconSize, weight: .semibold))
            Text(displayName)
                .font(.system(size: size.textSize, weight: .semibold, design: .monospaced))
            if let detail = displayDetail {
                Text(detail)
                    .font(.system(size: size.textSize, design: .monospaced))
                    .opacity(0.85)
            }
        }
        .foregroundColor(toolCallColor(for: name, input: input))
    }

    private var isMemoryCommand: Bool {
        guard name == "Bash", let input = input else { return false }
        return input.hasPrefix("cloude memory ")
    }

    private var isScript: Bool {
        guard name == "Bash", let input = input else { return false }
        return BashCommandParser.isScript(input)
    }

    private var displayName: String {
        if name == "Skill", let input = input, !input.isEmpty {
            let skillName = input.split(separator: ":", maxSplits: 1).first.map(String.init) ?? input
            return "/\(skillName)"
        }
        guard name == "Bash", let input = input, !input.isEmpty else { return name }
        if isMemoryCommand { return "Memory" }
        if isScript { return "Script" }
        let parsed = BashCommandParser.parse(input)
        var cmd = parsed.command
        if cmd.isEmpty { return name }
        if cmd.contains("/") {
            cmd = (cmd as NSString).lastPathComponent
        }
        if let sub = parsed.subcommand, ["git", "npm", "yarn", "pnpm", "bun", "cargo", "docker", "kubectl", "pip", "pip3", "swift", "claude"].contains(cmd) {
            let combined = "\(cmd) \(sub)"
            return midTruncate(combined, maxLength: 24)
        }
        return midTruncate(cmd, maxLength: 20)
    }

    private var displayDetail: String? {
        guard let input = input, !input.isEmpty else { return nil }

        switch name {
        case "Read", "Write", "Edit":
            let filename = (input as NSString).lastPathComponent
            return truncateFilename(filename, maxLength: 16)
        case "Bash":
            if isMemoryCommand {
                let parts = input.split(separator: " ", maxSplits: 3)
                if parts.count >= 4 {
                    let text = String(parts[3])
                    let truncated = text.prefix(24)
                    return truncated.count < text.count ? "\(truncated)..." : text
                }
                return nil
            }
            if isScript { return nil }
            return bashDisplayDetail(input)
        case "Glob", "Grep":
            let truncated = input.prefix(16)
            return truncated.count < input.count ? "\(truncated)..." : String(input)
        case "Skill":
            let parts = input.split(separator: ":", maxSplits: 1)
            if parts.count >= 2 {
                let args = String(parts[1]).trimmingCharacters(in: .whitespaces)
                let truncated = args.prefix(32)
                return truncated.count < args.count ? "\(truncated)..." : args
            }
            return nil
        case "Task":
            let parts = input.split(separator: ":", maxSplits: 1)
            return parts.first.map(String.init)
        default:
            return nil
        }
    }

    private func bashDisplayDetail(_ cmd: String) -> String {
        let parsed = BashCommandParser.parse(cmd)
        switch parsed.command {
        case "ls":
            if let path = parsed.firstArg {
                return truncatePath(path, maxLength: 18)
            }
            return "."
        case "cd":
            if let path = parsed.firstArg {
                return truncatePath(path, maxLength: 18)
            }
            return "~"
        case "git":
            if let arg = parsed.allArgs.first {
                return midTruncate(arg, maxLength: 20)
            }
            return ""
        case "npm", "yarn", "pnpm", "bun":
            return parsed.allArgs.first ?? ""
        case "cargo":
            return parsed.allArgs.first ?? ""
        case "pip", "pip3":
            return parsed.allArgs.first ?? ""
        case "make":
            return parsed.firstArg ?? "all"
        case "python", "python3":
            if let file = parsed.firstArg {
                return truncateFilename(file, maxLength: 16)
            }
            return ""
        case "node":
            if let file = parsed.firstArg {
                return truncateFilename(file, maxLength: 16)
            }
            return ""
        case "swift":
            return parsed.allArgs.first ?? ""
        case "xcodebuild":
            if let scheme = parsed.flagValue("-scheme") {
                return scheme
            }
            return parsed.subcommand ?? "build"
        case "fastlane":
            return parsed.allArgs.prefix(2).joined(separator: " ")
        case "docker":
            return parsed.allArgs.first ?? ""
        case "kubectl":
            return parsed.allArgs.first ?? ""
        case "cat", "head", "tail":
            if let file = parsed.firstArg {
                return truncateFilename((file as NSString).lastPathComponent, maxLength: 16)
            }
            return ""
        case "mkdir":
            if let dir = parsed.firstArg {
                return truncatePath(dir, maxLength: 18)
            }
            return ""
        case "rm":
            if let target = parsed.firstArg {
                return truncatePath(target, maxLength: 18)
            }
            return ""
        case "cp", "mv":
            let args = parsed.allArgs
            if args.count >= 2 {
                return "→ \(truncatePath(args.last!, maxLength: 14))"
            } else if let src = args.first {
                return truncatePath(src, maxLength: 18)
            }
            return ""
        case "chmod":
            let args = parsed.allArgs
            if args.count >= 2 {
                return "\(args[0]) \(truncatePath(args[1], maxLength: 12))"
            }
            return ""
        case "curl", "wget":
            if let url = parsed.firstArg {
                return truncateURL(url, maxLength: 20)
            }
            return ""
        case "grep", "rg":
            if let pattern = parsed.firstArg {
                let truncated = pattern.prefix(16)
                return truncated.count < pattern.count ? "\(truncated)..." : String(pattern)
            }
            return ""
        case "find":
            if let path = parsed.firstArg {
                return truncatePath(path, maxLength: 18)
            }
            return "."
        case "echo":
            let text = parsed.allArgs.joined(separator: " ")
            let truncated = text.prefix(18)
            return truncated.count < text.count ? "\(truncated)..." : String(text)
        case "source":
            if let file = parsed.firstArg {
                return truncateFilename((file as NSString).lastPathComponent, maxLength: 16)
            }
            return ""
        case "export":
            if let assignment = parsed.firstArg {
                let key = assignment.split(separator: "=").first.map(String.init) ?? assignment
                return key
            }
            return ""
        case "cloude":
            return parsed.subcommand ?? ""
        case "claude":
            if let arg = parsed.allArgs.first {
                return midTruncate(arg, maxLength: 20)
            }
            return ""
        default:
            return ""
        }
    }

    private func truncatePath(_ path: String, maxLength: Int) -> String {
        guard path.count > maxLength else { return path }
        let components = path.split(separator: "/")
        if components.count <= 1 {
            return String(path.suffix(maxLength - 1)) + "…"
        }
        let last = components.last!
        if last.count >= maxLength - 3 {
            return "…/\(last.suffix(maxLength - 3))"
        }
        return "…/\(last)"
    }

    private func truncateURL(_ url: String, maxLength: Int) -> String {
        var clean = url
        if clean.hasPrefix("https://") { clean = String(clean.dropFirst(8)) }
        else if clean.hasPrefix("http://") { clean = String(clean.dropFirst(7)) }
        if clean.hasPrefix("www.") { clean = String(clean.dropFirst(4)) }
        guard clean.count > maxLength else { return clean }
        return String(clean.prefix(maxLength - 1)) + "…"
    }

    private func truncateFilename(_ filename: String, maxLength: Int) -> String {
        guard filename.count > maxLength else { return filename }
        let ext = (filename as NSString).pathExtension
        let name = (filename as NSString).deletingPathExtension
        let availableLength = maxLength - ext.count - (ext.isEmpty ? 0 : 4)
        guard availableLength > 0 else { return filename }
        return "\(name.prefix(availableLength))….\(ext)"
    }

    private func midTruncate(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let half = (maxLength - 1) / 2
        let start = text.prefix(half)
        let end = text.suffix(half)
        return "\(start)…\(end)"
    }

    var iconName: String {
        switch name {
        case "Bash":
            if isMemoryCommand { return "brain" }
            if isScript { return "scroll" }
            return bashIconName(input ?? "")
        case "Read": return "doc.text"
        case "Write": return "doc.badge.plus"
        case "Edit": return "pencil.line"
        case "Glob": return "folder.badge.magnifyingglass"
        case "Grep": return "magnifyingglass"
        case "Task": return "person.2"
        case "WebFetch": return "globe"
        case "WebSearch": return "magnifyingglass.circle"
        case "TodoWrite": return "checklist"
        case "AskUserQuestion": return "questionmark.bubble"
        case "NotebookEdit": return "text.book.closed"
        case "Skill": return "command"
        case "Memory": return "brain"
        default: return "gear"
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

func toolCallColor(for name: String, input: String? = nil) -> Color {
    if name == "Bash", let cmd = input {
        if cmd.hasPrefix("cloude memory ") { return .pink }
        if BashCommandParser.isScript(cmd) { return .teal }
        return bashCommandColor(cmd)
    }
    switch name {
    case "Read": return .blue
    case "Write", "Edit": return .orange
    case "Bash": return .green
    case "Glob": return .purple
    case "Grep": return .pink
    case "Task": return .cyan
    case "WebFetch", "WebSearch": return .indigo
    case "TodoWrite": return .mint
    case "Skill": return .purple
    case "NotebookEdit": return .purple
    case "AskUserQuestion": return .orange
    case "Memory": return .pink
    default: return .secondary
    }
}
