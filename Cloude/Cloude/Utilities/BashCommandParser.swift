import Foundation

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
        if isScript(input) {
            return [input]
        }

        var commands: [String] = []
        var current = ""
        var inQuote: Character?
        var escape = false
        var i = input.startIndex

        while i < input.endIndex {
            let char = input[i]
            if escape {
                current.append(char)
                escape = false
            } else if char == "\\" {
                escape = true
                current.append(char)
            } else if let q = inQuote {
                current.append(char)
                if char == q { inQuote = nil }
            } else if char == "\"" || char == "'" {
                inQuote = char
                current.append(char)
            } else if char == "&" {
                let next = input.index(after: i)
                if next < input.endIndex && input[next] == "&" {
                    let trimmed = current.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { commands.append(trimmed) }
                    current = ""
                    i = input.index(after: next)
                    continue
                } else {
                    current.append(char)
                }
            } else if char == ";" {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { commands.append(trimmed) }
                current = ""
            } else {
                current.append(char)
            }
            i = input.index(after: i)
        }

        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { commands.append(trimmed) }
        return commands
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
