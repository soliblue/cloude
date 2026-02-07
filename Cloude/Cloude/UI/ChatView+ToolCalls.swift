import SwiftUI
import CloudeShared

struct ToolCallLabel: View {
    let name: String
    let input: String?
    var size: Size = .regular

    enum Size {
        case regular
        case small

        var iconSize: CGFloat { self == .regular ? 13 : 12 }
        var textSize: CGFloat { self == .regular ? 11 : 10 }
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
        if name == "TodoWrite" { return "Tasks" }
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
            cmd = cmd.lastPathComponent
        }
        if let sub = parsed.subcommand, ["git", "npm", "yarn", "pnpm", "bun", "cargo", "docker", "kubectl", "pip", "pip3", "swift", "claude"].contains(cmd) {
            let combined = "\(cmd) \(sub)"
            return midTruncate(combined, maxLength: 12)
        }
        return midTruncate(cmd, maxLength: 10)
    }

    private var displayDetail: String? {
        guard let input = input, !input.isEmpty else { return nil }

        switch name {
        case "Read", "Write", "Edit":
            let filename = input.lastPathComponent
            return truncateFilename(filename, maxLength: 8)
        case "Bash":
            if isMemoryCommand {
                let parts = input.split(separator: " ", maxSplits: 3)
                if parts.count >= 4 {
                    let text = String(parts[3])
                    let truncated = text.prefix(12)
                    return truncated.count < text.count ? "\(truncated)..." : text
                }
                return nil
            }
            if isScript { return nil }
            return bashDisplayDetail(input)
        case "Glob", "Grep":
            let truncated = input.prefix(8)
            return truncated.count < input.count ? "\(truncated)..." : String(input)
        case "Skill":
            let parts = input.split(separator: ":", maxSplits: 1)
            if parts.count >= 2 {
                let args = String(parts[1]).trimmingCharacters(in: .whitespaces)
                let truncated = args.prefix(16)
                return truncated.count < args.count ? "\(truncated)..." : args
            }
            return nil
        case "Task":
            let parts = input.split(separator: ":", maxSplits: 1)
            return parts.first.map(String.init)
        case "TodoWrite":
            if let data = input.data(using: .utf8),
               let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let completed = items.filter { ($0["status"] as? String) == "completed" }.count
                return "\(completed)/\(items.count)"
            }
            return nil
        default:
            return nil
        }
    }

    private func bashDisplayDetail(_ cmd: String) -> String {
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
        case "cloude":                      return parsed.subcommand ?? ""
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
        if args.count >= 2 { return "→ \(truncatePath(args.last!, maxLength: 7))" }
        return args.first.map { truncatePath($0, maxLength: 9) } ?? ""
    }

    private func chmodDetail(_ parsed: BashCommandParser) -> String {
        let args = parsed.allArgs
        guard args.count >= 2 else { return "" }
        return "\(args[0]) \(truncatePath(args[1], maxLength: 6))"
    }

    private func truncateText(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        return String(text.prefix(maxLength - 1)) + "…"
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
        let ext = filename.pathExtension
        let name = filename.deletingPathExtension
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
