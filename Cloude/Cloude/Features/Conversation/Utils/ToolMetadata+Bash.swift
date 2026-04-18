import SwiftUI
import CloudeShared

extension ToolMetadata {
    var bashDisplayName: String {
        guard let input, !input.isEmpty else { return name }
        if isScript { return "Script" }
        let parsed = BashCommandParser.parse(input)
        var cmd = parsed.command
        if cmd.isEmpty { return name }
        if cmd.contains("/") { cmd = cmd.lastPathComponent }
        if let sub = parsed.subcommand, Self.subcommandParents.contains(cmd) {
            return "\(cmd) \(sub)".middleTruncated(limit: 12)
        }
        return cmd.middleTruncated(limit: 10)
    }

    func bashDetail(_ cmd: String) -> String? {
        let parsed = BashCommandParser.parse(cmd)
        switch parsed.command {
        case "ls": return parsed.firstArg?.truncatedPath(limit: 9) ?? "."
        case "cd": return parsed.firstArg?.truncatedPath(limit: 9) ?? "~"
        case "mkdir", "rm", "find": return parsed.firstArg?.truncatedPath(limit: 9)
        case "cat", "head", "tail", "source", "python", "python3", "node":
            return parsed.firstArg?.lastPathComponent.truncatedFilename(limit: 8)
        case "xcodebuild": return parsed.flagValue("-scheme") ?? parsed.subcommand ?? "build"
        case "cp", "mv":
            if let last = parsed.allArgs.last, parsed.allArgs.count >= 2 { return "→ \(last.truncatedPath(limit: 7))" }
            return parsed.firstArg?.truncatedPath(limit: 9)
        case "curl", "wget": return parsed.firstArg?.truncatedURL(limit: 10)
        case "grep", "rg": return parsed.firstArg?.truncated(limit: 8)
        case "echo": return parsed.allArgs.joined(separator: " ").truncated(limit: 9)
        case "export": return parsed.firstArg.map { $0.split(separator: "=").first.map(String.init) ?? $0 }
        default: return nil
        }
    }

    func bashIcon(_ cmd: String) -> String {
        let parsed = BashCommandParser.parse(cmd)
        if let sub = parsed.subcommand, let icons = Self.subcommandIcons[parsed.command] {
            return icons[sub] ?? Self.parentDefaults[parsed.command] ?? "terminal"
        }
        return Self.bashIcons[parsed.command] ?? "terminal"
    }

    func bashColor(_ cmd: String) -> Color {
        AppColor.bashCommand(BashCommandParser.parse(cmd).command)
    }

    private static let subcommandParents: Set<String> = [
        "git", "npm", "yarn", "pnpm", "bun", "cargo", "docker", "kubectl", "pip", "pip3", "swift", "claude"
    ]

    private static let bashIcons: [String: String] = [
        "ls": "list.bullet", "cd": "folder", "pwd": "location",
        "mkdir": "folder.badge.plus", "rm": "trash", "rmdir": "folder.badge.minus",
        "cp": "doc.on.doc", "mv": "arrow.right.doc.on.clipboard",
        "touch": "doc.badge.plus", "cat": "doc.text", "head": "doc.text", "tail": "doc.text",
        "chmod": "lock.shield", "chown": "lock.shield",
        "python": "chevron.left.forwardslash.chevron.right",
        "python3": "chevron.left.forwardslash.chevron.right",
        "node": "chevron.left.forwardslash.chevron.right",
        "xcodebuild": "hammer", "fastlane": "airplane", "make": "hammer",
        "curl": "arrow.down.circle", "wget": "arrow.down.circle",
        "grep": "magnifyingglass", "rg": "magnifyingglass", "find": "folder.badge.questionmark",
        "echo": "text.bubble", "source": "arrow.right.circle",
        "ssh": "server.rack", "tar": "archivebox", "zip": "archivebox", "unzip": "archivebox",
        "brew": "mug", "cloude": "message.badge.waveform", "claude": "brain.head.profile",
        "pytest": "checkmark.diamond", "jest": "checkmark.diamond",
        "vim": "pencil.and.outline", "nvim": "pencil.and.outline",
        "code": "chevron.left.forwardslash.chevron.right",
        "kill": "xmark.circle", "open": "arrow.up.forward.square",
        "diff": "plus.forwardslash.minus", "wc": "number", "sort": "arrow.up.arrow.down"
    ]

    private static let subcommandIcons: [String: [String: String]] = [
        "git": [
            "commit": "checkmark.circle", "push": "arrow.up.circle",
            "pull": "arrow.down.circle", "clone": "square.and.arrow.down",
            "branch": "arrow.triangle.branch", "checkout": "arrow.triangle.swap",
            "switch": "arrow.triangle.swap", "merge": "arrow.triangle.merge",
            "rebase": "arrow.triangle.capsulepath", "status": "questionmark.folder",
            "diff": "plus.forwardslash.minus", "log": "clock.arrow.circlepath",
            "stash": "tray.and.arrow.down", "fetch": "arrow.down.doc",
            "reset": "arrow.uturn.backward.circle", "add": "plus.circle",
            "init": "sparkles", "remote": "network"
        ],
        "npm": [
            "install": "square.and.arrow.down", "i": "square.and.arrow.down",
            "run": "play", "start": "play", "test": "checkmark.diamond",
            "build": "hammer", "publish": "paperplane", "init": "sparkles",
            "uninstall": "trash", "update": "arrow.up.circle"
        ],
        "cargo": [
            "build": "hammer", "run": "play", "test": "checkmark.diamond",
            "new": "sparkles", "init": "sparkles", "publish": "paperplane",
            "add": "plus.circle", "remove": "minus.circle"
        ],
        "pip": [
            "install": "square.and.arrow.down", "uninstall": "trash",
            "list": "list.bullet", "freeze": "snowflake"
        ],
        "swift": [
            "build": "hammer", "run": "play", "test": "checkmark.diamond", "package": "shippingbox"
        ],
        "docker": [
            "build": "hammer", "run": "play", "push": "arrow.up.circle",
            "pull": "arrow.down.circle", "stop": "stop", "ps": "list.bullet",
            "rm": "trash", "rmi": "trash"
        ],
        "kubectl": [
            "get": "list.bullet", "apply": "checkmark.circle", "delete": "trash",
            "describe": "doc.text.magnifyingglass", "logs": "text.alignleft", "exec": "terminal"
        ]
    ]

    private static let parentDefaults: [String: String] = [
        "git": "arrow.triangle.branch", "npm": "shippingbox", "yarn": "shippingbox",
        "pnpm": "shippingbox", "bun": "shippingbox", "cargo": "gearshape.2",
        "pip": "cube", "pip3": "cube", "swift": "swift",
        "docker": "shippingbox", "kubectl": "server.rack"
    ]
}
