import SwiftUI

extension AppColor {
    static func tool(_ name: String) -> Color {
        switch name {
        case "Read": return blue
        case "Write", "Edit", "AskUserQuestion": return orange
        case "Glob", "Skill", "NotebookEdit": return purple
        case "Grep": return pink
        case "Task", "TeamCreate", "TeamDelete": return cyan
        case "WebFetch", "WebSearch": return indigo
        case "TodoWrite": return mint
        case "SendMessage": return teal
        case "Agent": return yellow
        default: return .secondary
        }
    }

    static func bashCommand(_ command: String) -> Color {
        switch command {
        case "cargo", "rs": return rust
        case "git", "swift", "xcodebuild", "fastlane": return orange
        case "npm", "yarn", "pnpm", "bun", "rm", "kill", "killall": return red
        case "node", "pytest", "jest", "mocha", "vitest": return green
        case "python", "python3", "pip", "pip3", "brew": return yellow
        case "ls", "cd", "pwd", "mkdir", "rmdir": return cyan
        case "cp", "mv": return teal
        case "cat", "head", "tail", "less", "more", "docker", "kubectl": return blue
        case "curl", "wget", "ssh", "scp", "rsync": return indigo
        case "grep", "rg", "ag", "find", "fd": return pink
        case "tar", "zip", "unzip", "gzip": return brown
        case "vim", "nvim", "nano", "emacs", "code", "eslint", "prettier", "rubocop", "claude": return purple
        case "cloude": return .accentColor
        default: return green
        }
    }

    static func fileExtension(_ ext: String) -> Color {
        switch ext {
        case "swift", "xcodeproj", "xcworkspace": return orange
        case "py", "js", "jsx", "json", "env": return yellow
        case "ts", "tsx", "css", "scss", "sass", "less": return blue
        case "go": return cyan
        case "rs": return rust
        case "rb", "pdf": return red
        case "java", "kt", "html", "xml", "plist": return orange
        case "yaml", "yml", "toml", "mp3", "wav", "aac", "flac", "ogg", "m4a": return pink
        case "sh", "bash", "zsh", "fish": return green
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg": return purple
        case "mp4", "mov", "avi", "mkv", "webm": return indigo
        case "zip", "tar", "gz", "rar", "7z": return brown
        case "lock": return gray
        default: return .secondary
        }
    }

    static func gitStatus(_ status: String) -> Color {
        switch status {
        case "M": return orange
        case "A": return success
        case "D": return danger
        case "R", "C": return blue
        case "??": return gray
        default: return .secondary
        }
    }

    static func todoStatus(_ status: String) -> Color {
        switch status {
        case "completed": return success
        case "in_progress": return mint
        default: return .secondary
        }
    }
}
