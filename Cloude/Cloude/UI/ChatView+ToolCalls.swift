import SwiftUI

private let bashIconMap: [String: String] = [
    "ls": "list.bullet",
    "cd": "folder",
    "pwd": "location",
    "mkdir": "folder.badge.plus",
    "rm": "trash",
    "rmdir": "folder.badge.minus",
    "cp": "doc.on.doc",
    "mv": "arrow.right.doc.on.clipboard",
    "touch": "doc.badge.plus",
    "cat": "doc.text",
    "head": "doc.text",
    "tail": "doc.text",
    "less": "doc.text",
    "more": "doc.text",
    "chmod": "lock.shield",
    "chown": "lock.shield",
    "python": "chevron.left.forwardslash.chevron.right",
    "python3": "chevron.left.forwardslash.chevron.right",
    "node": "chevron.left.forwardslash.chevron.right",
    "xcodebuild": "hammer",
    "fastlane": "airplane",
    "make": "hammer",
    "curl": "arrow.down.circle",
    "wget": "arrow.down.circle",
    "grep": "magnifyingglass",
    "rg": "magnifyingglass",
    "ag": "magnifyingglass",
    "find": "folder.badge.questionmark",
    "fd": "folder.badge.questionmark",
    "echo": "text.bubble",
    "printf": "text.bubble",
    "export": "gearshape",
    "env": "gearshape",
    "source": "arrow.right.circle",
    ".": "arrow.right.circle",
    "ssh": "server.rack",
    "scp": "arrow.left.arrow.right",
    "rsync": "arrow.left.arrow.right",
    "tar": "archivebox",
    "zip": "archivebox",
    "unzip": "archivebox",
    "gzip": "archivebox",
    "brew": "mug",
    "cloude": "message.badge.waveform",
    "claude": "brain.head.profile",
    "pytest": "checkmark.diamond",
    "jest": "checkmark.diamond",
    "mocha": "checkmark.diamond",
    "vitest": "checkmark.diamond",
    "eslint": "wand.and.stars",
    "prettier": "wand.and.stars",
    "rubocop": "wand.and.stars",
    "code": "chevron.left.forwardslash.chevron.right",
    "vim": "pencil.and.outline",
    "nvim": "pencil.and.outline",
    "nano": "pencil.and.outline",
    "emacs": "pencil.and.outline",
    "man": "questionmark.circle",
    "help": "questionmark.circle",
    "which": "location.magnifyingglass",
    "whereis": "location.magnifyingglass",
    "type": "location.magnifyingglass",
    "ps": "cpu",
    "top": "cpu",
    "htop": "cpu",
    "kill": "xmark.circle",
    "killall": "xmark.circle",
    "open": "arrow.up.forward.square",
    "pbcopy": "doc.on.clipboard",
    "pbpaste": "doc.on.clipboard",
    "date": "calendar",
    "whoami": "person",
    "sleep": "moon.zzz",
    "clear": "eraser",
    "history": "clock.arrow.circlepath",
    "alias": "link",
    "wc": "number",
    "sort": "arrow.up.arrow.down",
    "uniq": "star",
    "diff": "plus.forwardslash.minus",
    "sed": "text.magnifyingglass",
    "awk": "text.magnifyingglass",
    "tee": "arrow.triangle.branch",
    "xargs": "arrow.right.to.line"
]

private let gitSubcommandIcons: [String: String] = [
    "commit": "checkmark.circle",
    "push": "arrow.up.circle",
    "pull": "arrow.down.circle",
    "clone": "square.and.arrow.down",
    "branch": "arrow.triangle.branch",
    "checkout": "arrow.triangle.swap",
    "switch": "arrow.triangle.swap",
    "merge": "arrow.triangle.merge",
    "rebase": "arrow.triangle.capsulepath",
    "status": "questionmark.folder",
    "diff": "plus.forwardslash.minus",
    "log": "clock.arrow.circlepath",
    "stash": "tray.and.arrow.down",
    "fetch": "arrow.down.doc",
    "reset": "arrow.uturn.backward.circle",
    "add": "plus.circle",
    "init": "sparkles",
    "remote": "network"
]

private let npmSubcommandIcons: [String: String] = [
    "install": "square.and.arrow.down",
    "i": "square.and.arrow.down",
    "add": "square.and.arrow.down",
    "run": "play",
    "start": "play",
    "test": "checkmark.diamond",
    "build": "hammer",
    "publish": "paperplane",
    "init": "sparkles",
    "uninstall": "trash",
    "remove": "trash",
    "rm": "trash",
    "update": "arrow.up.circle",
    "upgrade": "arrow.up.circle"
]

private let cargoSubcommandIcons: [String: String] = [
    "build": "hammer",
    "run": "play",
    "test": "checkmark.diamond",
    "new": "sparkles",
    "init": "sparkles",
    "publish": "paperplane",
    "add": "plus.circle",
    "remove": "minus.circle",
    "update": "arrow.up.circle"
]

private let pipSubcommandIcons: [String: String] = [
    "install": "square.and.arrow.down",
    "uninstall": "trash",
    "list": "list.bullet",
    "freeze": "snowflake"
]

private let swiftSubcommandIcons: [String: String] = [
    "build": "hammer",
    "run": "play",
    "test": "checkmark.diamond",
    "package": "shippingbox"
]

private let dockerSubcommandIcons: [String: String] = [
    "build": "hammer",
    "run": "play",
    "push": "arrow.up.circle",
    "pull": "arrow.down.circle",
    "stop": "stop",
    "ps": "list.bullet",
    "ls": "list.bullet",
    "rm": "trash",
    "rmi": "trash"
]

private let kubectlSubcommandIcons: [String: String] = [
    "get": "list.bullet",
    "apply": "checkmark.circle",
    "delete": "trash",
    "describe": "doc.text.magnifyingglass",
    "logs": "text.alignleft",
    "exec": "terminal"
]

private let bashColorMap: [String: Color] = [
    "cloude": .accentColor,
    "claude": .purple,
    "git": .orange,
    "npm": .red,
    "yarn": .red,
    "pnpm": .red,
    "bun": .red,
    "node": .green,
    "swift": .orange,
    "xcodebuild": .orange,
    "fastlane": .orange,
    "docker": .blue,
    "kubectl": .blue,
    "make": .purple,
    "ls": .cyan,
    "cd": .cyan,
    "pwd": .cyan,
    "mkdir": .cyan,
    "rmdir": .cyan,
    "rm": .red,
    "kill": .red,
    "killall": .red,
    "cp": .teal,
    "mv": .teal,
    "cat": .blue,
    "head": .blue,
    "tail": .blue,
    "less": .blue,
    "more": .blue,
    "curl": .indigo,
    "wget": .indigo,
    "ssh": .indigo,
    "scp": .indigo,
    "rsync": .indigo,
    "grep": .pink,
    "rg": .pink,
    "ag": .pink,
    "find": .pink,
    "fd": .pink,
    "brew": .yellow,
    "tar": .brown,
    "zip": .brown,
    "unzip": .brown,
    "gzip": .brown,
    "vim": .purple,
    "nvim": .purple,
    "nano": .purple,
    "emacs": .purple,
    "code": .purple,
    "pytest": .green,
    "jest": .green,
    "mocha": .green,
    "vitest": .green,
    "eslint": .purple,
    "prettier": .purple,
    "rubocop": .purple,
    "pip": .yellow,
    "pip3": .yellow,
    "python": .yellow,
    "python3": .yellow
]

private let cargoColor = Color(red: 0.87, green: 0.46, blue: 0.19)

struct BashCommandParser {
    let command: String
    let subcommand: String?
    let firstArg: String?
    let allArgs: [String]
    private let flags: [String: String]

    static func parse(_ input: String) -> BashCommandParser {
        let tokens = tokenize(input)
        guard let cmd = tokens.first else {
            return BashCommandParser(command: "", subcommand: nil, firstArg: nil, allArgs: [], flags: [:])
        }

        var subcommand: String?
        var args: [String] = []
        var flags: [String: String] = [:]
        var i = 1

        while i < tokens.count {
            let token = tokens[i]
            if token.hasPrefix("-") {
                if i + 1 < tokens.count && !tokens[i + 1].hasPrefix("-") {
                    flags[token] = tokens[i + 1]
                    i += 2
                } else {
                    flags[token] = ""
                    i += 1
                }
            } else {
                if subcommand == nil && ["git", "npm", "yarn", "pnpm", "bun", "cargo", "pip", "pip3", "swift", "docker", "kubectl", "cloude", "claude", "fastlane", "xcodebuild"].contains(cmd) {
                    subcommand = token
                } else {
                    args.append(token)
                }
                i += 1
            }
        }

        return BashCommandParser(
            command: cmd,
            subcommand: subcommand,
            firstArg: subcommand == nil ? args.first : (args.first ?? subcommand),
            allArgs: args,
            flags: flags
        )
    }

    func flagValue(_ flag: String) -> String? {
        if let v = flags[flag], !v.isEmpty { return v }
        return nil
    }

    private static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuote: Character?
        var escape = false

        for char in input {
            if escape {
                current.append(char)
                escape = false
            } else if char == "\\" {
                escape = true
            } else if let q = inQuote {
                if char == q {
                    inQuote = nil
                } else {
                    current.append(char)
                }
            } else if char == "\"" || char == "'" {
                inQuote = char
            } else if char == " " || char == "\t" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else if char == "&" || char == "|" || char == ";" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                break
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
}

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

    private var displayName: String {
        guard name == "Bash", let input = input, !input.isEmpty else { return name }
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
            return bashDisplayDetail(input)
        case "Glob", "Grep":
            let truncated = input.prefix(16)
            return truncated.count < input.count ? "\(truncated)..." : String(input)
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

    private var iconName: String {
        switch name {
        case "Bash":
            return bashIconName(input ?? "")
        case "Read": return "eyeglasses"
        case "Write": return "doc.badge.plus"
        case "Edit": return "pencil"
        case "Glob": return "folder.badge.questionmark"
        case "Grep": return "magnifyingglass"
        case "Task": return "arrow.trianglehead.branch"
        case "WebFetch": return "globe"
        case "WebSearch": return "magnifyingglass.circle"
        case "TodoWrite": return "checklist"
        case "AskUserQuestion": return "questionmark.bubble"
        case "NotebookEdit": return "text.book.closed"
        case "Memory": return "brain.head.profile"
        default: return "bolt"
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
    case "NotebookEdit": return .purple
    case "AskUserQuestion": return .orange
    case "Memory": return .pink
    default: return .secondary
    }
}

private func bashCommandColor(_ cmd: String) -> Color {
    let parsed = BashCommandParser.parse(cmd)
    if parsed.command == "cargo" {
        return cargoColor
    }
    return bashColorMap[parsed.command] ?? .green
}
