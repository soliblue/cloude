//
//  RichTextView+Tables.swift
//  Cloude
//

import Foundation

extension MarkdownParser {
    static func parseTextAndTables(_ text: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let lines = text.components(separatedBy: "\n")
        var currentText: [String] = []
        var tableRows: [[String]] = []
        var blockquoteLines: [String] = []
        var inTable = false
        var inBlockquote = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isTableRow = line.contains("|") && trimmed.hasPrefix("|")
            let isSeparator = line.contains("|") && line.contains("-") && !line.contains(where: { $0.isLetter })
            let isBlockquote = trimmed.hasPrefix(">")
            let isHorizontalRule = isHorizontalRuleLine(trimmed)

            if isHorizontalRule {
                if inBlockquote && !blockquoteLines.isEmpty {
                    blocks.append(.blockquote(blockquoteLines.joined(separator: "\n")))
                    blockquoteLines = []
                    inBlockquote = false
                }
                if inTable && !tableRows.isEmpty {
                    blocks.append(.table(tableRows))
                    tableRows = []
                    inTable = false
                }
                if !currentText.isEmpty {
                    let joined = currentText.joined(separator: "\n")
                    if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        blocks.append(.text(joined))
                    }
                    currentText = []
                }
                blocks.append(.horizontalRule)
            } else if isBlockquote {
                if !inBlockquote {
                    if !currentText.isEmpty {
                        blocks.append(.text(currentText.joined(separator: "\n")))
                        currentText = []
                    }
                    if inTable && !tableRows.isEmpty {
                        blocks.append(.table(tableRows))
                        tableRows = []
                        inTable = false
                    }
                }
                inBlockquote = true
                let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                blockquoteLines.append(content)
            } else if isTableRow && !isSeparator {
                if inBlockquote && !blockquoteLines.isEmpty {
                    blocks.append(.blockquote(blockquoteLines.joined(separator: "\n")))
                    blockquoteLines = []
                    inBlockquote = false
                }
                if !inTable && !currentText.isEmpty {
                    blocks.append(.text(currentText.joined(separator: "\n")))
                    currentText = []
                }
                inTable = true
                let cells = line.split(separator: "|").map { String($0) }
                tableRows.append(cells)
            } else if isSeparator && inTable {
                continue
            } else {
                if inBlockquote && !blockquoteLines.isEmpty {
                    blocks.append(.blockquote(blockquoteLines.joined(separator: "\n")))
                    blockquoteLines = []
                    inBlockquote = false
                }
                if inTable && !tableRows.isEmpty {
                    blocks.append(.table(tableRows))
                    tableRows = []
                    inTable = false
                }
                currentText.append(line)
            }
        }

        if !blockquoteLines.isEmpty {
            blocks.append(.blockquote(blockquoteLines.joined(separator: "\n")))
        }
        if !tableRows.isEmpty {
            blocks.append(.table(tableRows))
        }
        if !currentText.isEmpty {
            let joined = currentText.joined(separator: "\n")
            if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.text(joined))
            }
        }

        return blocks
    }

    private static func isHorizontalRuleLine(_ line: String) -> Bool {
        guard line.count >= 2 else { return false }
        let dashOnly = line.allSatisfy { $0 == "-" || $0 == " " }
        let starOnly = line.allSatisfy { $0 == "*" || $0 == " " }
        let underscoreOnly = line.allSatisfy { $0 == "_" || $0 == " " }
        let dashCount = line.filter { $0 == "-" }.count
        let starCount = line.filter { $0 == "*" }.count
        let underscoreCount = line.filter { $0 == "_" }.count
        return (dashOnly && dashCount >= 2) || (starOnly && starCount >= 3) || (underscoreOnly && underscoreCount >= 3)
    }
}
