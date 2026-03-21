// BashCommandParser+Tokenizer.swift

import Foundation

extension BashCommandParser {
    static func splitChainedWithOperators(_ input: String) -> [ChainedCommand] {
        if isScript(input) || input.contains("<<") {
            return [ChainedCommand(command: input, operatorAfter: nil)]
        }

        var result: [ChainedCommand] = []
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
                    if !trimmed.isEmpty { result.append(ChainedCommand(command: trimmed, operatorAfter: .and)) }
                    current = ""
                    i = input.index(after: next)
                    continue
                } else {
                    current.append(char)
                }
            } else if char == "|" {
                let next = input.index(after: i)
                if next < input.endIndex && input[next] == "|" {
                    let trimmed = current.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { result.append(ChainedCommand(command: trimmed, operatorAfter: .or)) }
                    current = ""
                    i = input.index(after: next)
                    continue
                } else {
                    let trimmed = current.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { result.append(ChainedCommand(command: trimmed, operatorAfter: .pipe)) }
                    current = ""
                }
            } else if char == ";" {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { result.append(ChainedCommand(command: trimmed, operatorAfter: .semicolon)) }
                current = ""
            } else {
                current.append(char)
            }
            i = input.index(after: i)
        }

        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { result.append(ChainedCommand(command: trimmed, operatorAfter: nil)) }
        return result
    }

    static func tokenize(_ input: String) -> [String] {
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
