import SwiftUI

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
                if subcommand == nil && ["git", "npm", "yarn", "pnpm", "bun", "cargo", "pip", "pip3", "swift", "docker", "kubectl", "cloude", "fastlane", "xcodebuild"].contains(cmd) {
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
        let cmd = parsed.command
        if cmd.isEmpty { return name }
        if let sub = parsed.subcommand, ["git", "npm", "yarn", "pnpm", "bun", "cargo", "docker", "kubectl", "pip", "pip3", "swift"].contains(cmd) {
            return "\(cmd) \(sub)"
        }
        return cmd
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
            return parsed.subcommand ?? "status"
        case "npm", "yarn", "pnpm", "bun":
            return parsed.subcommand ?? "install"
        case "cargo":
            return parsed.subcommand ?? "build"
        case "pip", "pip3":
            return parsed.subcommand ?? "install"
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
            return parsed.subcommand ?? "build"
        case "xcodebuild":
            if let scheme = parsed.flagValue("-scheme") {
                return scheme
            }
            return parsed.subcommand ?? "build"
        case "fastlane":
            return parsed.allArgs.prefix(2).joined(separator: " ")
        case "docker":
            return parsed.subcommand ?? "run"
        case "kubectl":
            return parsed.subcommand ?? "get"
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
        default:
            let truncated = cmd.prefix(20)
            return truncated.count < cmd.count ? "\(truncated)..." : String(cmd)
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
        switch parsed.command {
        case "ls": return "list.bullet"
        case "cd": return "folder"
        case "pwd": return "location"
        case "mkdir": return "folder.badge.plus"
        case "rm": return "trash"
        case "rmdir": return "folder.badge.minus"
        case "cp": return "doc.on.doc"
        case "mv": return "arrow.right.doc.on.clipboard"
        case "touch": return "doc.badge.plus"
        case "cat", "head", "tail", "less", "more": return "doc.text"
        case "chmod", "chown": return "lock.shield"
        case "git":
            switch parsed.subcommand {
            case "commit": return "checkmark.circle"
            case "push": return "arrow.up.circle"
            case "pull": return "arrow.down.circle"
            case "clone": return "square.and.arrow.down"
            case "branch": return "arrow.triangle.branch"
            case "checkout", "switch": return "arrow.triangle.swap"
            case "merge": return "arrow.triangle.merge"
            case "rebase": return "arrow.triangle.capsulepath"
            case "status": return "questionmark.folder"
            case "diff": return "plus.forwardslash.minus"
            case "log": return "clock.arrow.circlepath"
            case "stash": return "tray.and.arrow.down"
            case "fetch": return "arrow.down.doc"
            case "reset": return "arrow.uturn.backward.circle"
            case "add": return "plus.circle"
            case "init": return "sparkles"
            case "remote": return "network"
            default: return "arrow.triangle.branch"
            }
        case "npm", "yarn", "pnpm", "bun":
            switch parsed.subcommand {
            case "install", "i", "add": return "square.and.arrow.down"
            case "run", "start": return "play"
            case "test": return "checkmark.diamond"
            case "build": return "hammer"
            case "publish": return "paperplane"
            case "init": return "sparkles"
            case "uninstall", "remove", "rm": return "trash"
            case "update", "upgrade": return "arrow.up.circle"
            default: return "shippingbox"
            }
        case "cargo":
            switch parsed.subcommand {
            case "build": return "hammer"
            case "run": return "play"
            case "test": return "checkmark.diamond"
            case "new", "init": return "sparkles"
            case "publish": return "paperplane"
            case "add": return "plus.circle"
            case "remove": return "minus.circle"
            case "update": return "arrow.up.circle"
            default: return "gearshape.2"
            }
        case "pip", "pip3":
            switch parsed.subcommand {
            case "install": return "square.and.arrow.down"
            case "uninstall": return "trash"
            case "list": return "list.bullet"
            case "freeze": return "snowflake"
            default: return "cube"
            }
        case "python", "python3": return "chevron.left.forwardslash.chevron.right"
        case "node": return "chevron.left.forwardslash.chevron.right"
        case "swift":
            switch parsed.subcommand {
            case "build": return "hammer"
            case "run": return "play"
            case "test": return "checkmark.diamond"
            case "package": return "shippingbox"
            default: return "swift"
            }
        case "xcodebuild": return "hammer"
        case "fastlane": return "airplane"
        case "make": return "hammer"
        case "docker":
            switch parsed.subcommand {
            case "build": return "hammer"
            case "run": return "play"
            case "push": return "arrow.up.circle"
            case "pull": return "arrow.down.circle"
            case "stop": return "stop"
            case "ps", "ls": return "list.bullet"
            case "rm", "rmi": return "trash"
            default: return "shippingbox"
            }
        case "kubectl":
            switch parsed.subcommand {
            case "get": return "list.bullet"
            case "apply": return "checkmark.circle"
            case "delete": return "trash"
            case "describe": return "doc.text.magnifyingglass"
            case "logs": return "text.alignleft"
            case "exec": return "terminal"
            default: return "server.rack"
            }
        case "curl", "wget": return "arrow.down.circle"
        case "grep", "rg", "ag": return "magnifyingglass"
        case "find", "fd": return "folder.badge.questionmark"
        case "echo", "printf": return "text.bubble"
        case "export", "env": return "gearshape"
        case "source", ".": return "arrow.right.circle"
        case "ssh": return "server.rack"
        case "scp", "rsync": return "arrow.left.arrow.right"
        case "tar", "zip", "unzip", "gzip": return "archivebox"
        case "brew": return "mug"
        case "cloude": return "message.badge.waveform"
        case "pytest", "jest", "mocha", "vitest": return "checkmark.diamond"
        case "eslint", "prettier", "rubocop": return "wand.and.stars"
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "vim", "nvim", "nano", "emacs": return "pencil.and.outline"
        case "man", "help": return "questionmark.circle"
        case "which", "whereis", "type": return "location.magnifyingglass"
        case "ps", "top", "htop": return "cpu"
        case "kill", "killall": return "xmark.circle"
        case "open": return "arrow.up.forward.square"
        case "pbcopy", "pbpaste": return "doc.on.clipboard"
        case "date": return "calendar"
        case "whoami": return "person"
        case "sleep": return "moon.zzz"
        case "clear": return "eraser"
        case "history": return "clock.arrow.circlepath"
        case "alias": return "link"
        case "wc": return "number"
        case "sort": return "arrow.up.arrow.down"
        case "uniq": return "star"
        case "diff": return "plus.forwardslash.minus"
        case "sed", "awk": return "text.magnifyingglass"
        case "tee": return "arrow.triangle.branch"
        case "xargs": return "arrow.right.to.line"
        default: return "terminal"
        }
    }
}

struct ToolCallsSection: View {
    let toolCalls: [ToolCall]
    @State private var expandedToolId: String?

    private var topLevelCalls: [ToolCall] {
        Array(toolCalls.filter { $0.parentToolId == nil }.reversed())
    }

    private func children(of toolId: String) -> [ToolCall] {
        toolCalls.filter { $0.parentToolId == toolId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(topLevelCalls, id: \.toolId) { toolCall in
                        ToolPill(
                            toolCall: toolCall,
                            childCount: children(of: toolCall.toolId).count,
                            isExpanded: expandedToolId == toolCall.toolId
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if expandedToolId == toolCall.toolId {
                                    expandedToolId = nil
                                } else if !children(of: toolCall.toolId).isEmpty {
                                    expandedToolId = toolCall.toolId
                                }
                            }
                        }
                    }
                }
                .animation(.easeOut(duration: 0.25), value: topLevelCalls.count)
            }

            if let expandedId = expandedToolId {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(children(of: expandedId).enumerated()), id: \.offset) { _, child in
                        ToolCallRow(name: child.name, input: child.input)
                    }
                }
                .padding(.leading, 8)
                .transition(.opacity)
            }
        }
    }
}

struct ToolPill: View {
    let toolCall: ToolCall
    let childCount: Int
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 4) {
            ToolCallLabel(name: toolCall.name, input: toolCall.input, size: .small)
            if childCount > 0 {
                Text("(\(childCount))")
                    .font(.system(size: 10))
                    .foregroundColor(toolCallColor(for: toolCall.name, input: toolCall.input))
                    .opacity(0.7)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(toolCallColor(for: toolCall.name, input: toolCall.input).opacity(isExpanded ? 0.2 : 0.12))
        .cornerRadius(14)
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
    switch parsed.command {
    case "cloude": return .accentColor
    case "git": return .orange
    case "npm", "yarn", "pnpm", "bun": return .red
    case "cargo": return Color(red: 0.87, green: 0.46, blue: 0.19)
    case "pip", "pip3", "python", "python3": return .yellow
    case "node": return .green
    case "swift", "xcodebuild", "fastlane": return .orange
    case "docker": return .blue
    case "kubectl": return .blue
    case "make": return .purple
    case "ls", "cd", "pwd", "mkdir", "rmdir": return .cyan
    case "rm", "kill", "killall": return .red
    case "cp", "mv": return .teal
    case "cat", "head", "tail", "less", "more": return .blue
    case "curl", "wget", "ssh", "scp", "rsync": return .indigo
    case "grep", "rg", "ag", "find", "fd": return .pink
    case "brew": return .yellow
    case "tar", "zip", "unzip", "gzip": return .brown
    case "vim", "nvim", "nano", "emacs", "code": return .purple
    case "pytest", "jest", "mocha", "vitest": return .green
    case "eslint", "prettier", "rubocop": return .purple
    default: return .green
    }
}
