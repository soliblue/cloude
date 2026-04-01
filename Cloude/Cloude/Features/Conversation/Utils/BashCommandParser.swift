// BashCommandParser.swift

import Foundation

enum ShellOperator: String {
    case and = "&&"
    case or = "||"
    case pipe = "|"
    case semicolon = ";"
}

struct ChainedCommand {
    let command: String
    let operatorAfter: ShellOperator?
}

struct BashCommandParser {
    let command: String
    let subcommand: String?
    let firstArg: String?
    let allArgs: [String]
    private let flags: [String: String]

    static func chainedCommands(for input: String) -> [String] {
        guard !isScript(input) else { return [] }
        let commands = splitChainedCommands(input)
        return commands.count > 1 ? commands : []
    }

    static func chainedCommandsWithOperators(for input: String) -> [ChainedCommand] {
        guard !isScript(input) else { return [] }
        let result = splitChainedWithOperators(input)
        return result.count > 1 ? result : []
    }

    static func isScript(_ input: String) -> Bool {
        let scriptPatterns = [
            "\\bfor\\b.*\\bdo\\b",
            "\\bwhile\\b.*\\bdo\\b",
            "\\buntil\\b.*\\bdo\\b",
            "\\bif\\b.*\\bthen\\b",
            "\\bcase\\b.*\\bin\\b",
            "\\bdone\\b",
            "\\bfi\\b",
            "\\besac\\b"
        ]
        for pattern in scriptPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil {
                return true
            }
        }
        return false
    }

    static func splitChainedCommands(_ input: String) -> [String] {
        splitChainedWithOperators(input).map(\.command)
    }

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
}
