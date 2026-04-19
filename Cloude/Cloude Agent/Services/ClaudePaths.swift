import Foundation

enum ClaudePaths {
    static func resolve() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(home)/.local/bin/claude",
            "\(home)/.npm-global/bin/claude"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "claude"
    }

    static func shellEscape(_ string: String) -> String {
        "'\(string.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
