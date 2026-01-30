//
//  MarkdownText+Blocks.swift
//  Cloude
//

import SwiftUI

struct CodeBlock: View {
    let code: String
    let language: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(SyntaxHighlighter.highlight(code, language: language))
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct SyntaxHighlighter {
    static let keywordColor = Color(.systemBlue)
    static let stringColor = Color(.systemGreen)
    static let commentColor = Color(.systemGray)
    static let numberColor = Color(.systemOrange)
    static let typeColor = Color(.systemPurple)

    static let keywords: Set<String> = [
        "func", "var", "let", "if", "else", "for", "while", "return", "import", "struct", "class", "enum", "switch", "case", "break", "continue", "guard", "defer", "try", "catch", "throw", "throws", "async", "await", "private", "public", "internal", "static", "override", "final", "self", "super", "init", "deinit", "extension", "protocol", "where", "in", "as", "is", "nil", "true", "false",
        "function", "const", "export", "default", "from", "new", "this", "typeof", "instanceof", "undefined", "null",
        "def", "elif", "pass", "with", "lambda", "yield", "global", "nonlocal", "assert", "raise", "except", "finally", "and", "or", "not", "None", "True", "False",
        "fn", "mut", "pub", "mod", "use", "impl", "trait", "match", "loop", "move", "ref", "unsafe", "extern", "crate", "type", "dyn", "Some", "Ok", "Err",
        "package", "go", "chan", "select", "range", "fallthrough", "make", "map", "interface", "iota"
    ]

    static let types: Set<String> = [
        "String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set", "Optional", "Result", "Error", "View", "some", "any", "Self",
        "number", "string", "boolean", "object", "void", "never", "unknown", "any",
        "str", "int", "float", "bool", "list", "dict", "tuple", "set", "bytes",
        "i8", "i16", "i32", "i64", "i128", "u8", "u16", "u32", "u64", "u128", "f32", "f64", "usize", "isize", "Vec", "Box", "Rc", "Arc", "Option"
    ]

    static func highlight(_ code: String, language: String?) -> AttributedString {
        var result = AttributedString()
        let lines = code.components(separatedBy: "\n")

        for (lineIndex, line) in lines.enumerated() {
            result.append(highlightLine(line, language: language))
            if lineIndex < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }

        return result
    }

    private static func highlightLine(_ line: String, language: String?) -> AttributedString {
        var result = AttributedString()
        var remaining = line[...]
        var inString: Character? = nil

        while !remaining.isEmpty {
            let char = remaining.first!

            if inString != nil {
                var stringContent = String(char)
                remaining = remaining.dropFirst()
                if char == inString {
                    inString = nil
                } else if char == "\\" && !remaining.isEmpty {
                    stringContent.append(remaining.first!)
                    remaining = remaining.dropFirst()
                }
                var attr = AttributedString(stringContent)
                attr.foregroundColor = stringColor
                result.append(attr)
                continue
            }

            if char == "\"" || char == "'" || char == "`" {
                inString = char
                var attr = AttributedString(String(char))
                attr.foregroundColor = stringColor
                result.append(attr)
                remaining = remaining.dropFirst()
                continue
            }

            if remaining.hasPrefix("//") || remaining.hasPrefix("#") && language != "bash" {
                var attr = AttributedString(String(remaining))
                attr.foregroundColor = commentColor
                result.append(attr)
                return result
            }

            if char.isLetter || char == "_" {
                var word = ""
                while let c = remaining.first, c.isLetter || c.isNumber || c == "_" {
                    word.append(c)
                    remaining = remaining.dropFirst()
                }
                var attr = AttributedString(word)
                if keywords.contains(word) {
                    attr.foregroundColor = keywordColor
                } else if types.contains(word) {
                    attr.foregroundColor = typeColor
                }
                result.append(attr)
                continue
            }

            if char.isNumber {
                var number = ""
                while let c = remaining.first, c.isNumber || c == "." || c == "x" || c == "b" || (c.isHexDigit && number.contains("x")) {
                    number.append(c)
                    remaining = remaining.dropFirst()
                }
                var attr = AttributedString(number)
                attr.foregroundColor = numberColor
                result.append(attr)
                continue
            }

            result.append(AttributedString(String(char)))
            remaining = remaining.dropFirst()
        }

        return result
    }
}

struct BlockquoteView: View {
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color(.systemGray3))
                .frame(width: 3)
            Text(text)
                .font(.body)
                .italic()
                .foregroundColor(.secondary)
                .padding(.leading, 12)
                .padding(.vertical, 4)
        }
    }
}

struct MarkdownTableView: View {
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            TableCell(text: cell.trimmingCharacters(in: .whitespaces), isHeader: rowIndex == 0)
                                .frame(minWidth: 60, alignment: .leading)
                        }
                    }
                    if rowIndex == 0 {
                        Divider()
                    }
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(6)
    }
}

struct TableCell: View {
    let text: String
    let isHeader: Bool

    var body: some View {
        Text(parseInlineMarkdown())
            .font(isHeader ? .caption.bold() : .caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }

    private func parseInlineMarkdown() -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }
        return AttributedString(text)
    }
}

struct HorizontalRuleView: View {
    var body: some View {
        Divider()
            .padding(.vertical, 8)
    }
}
