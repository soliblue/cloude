// XMLNode+Parser.swift

import Foundation

struct XMLBlockParser {
    private(set) var text: String
    var index: String.Index

    init(_ text: String) {
        self.text = text
        self.index = text.startIndex
    }

    mutating func parseNodes() -> [XMLNode] {
        var nodes: [XMLNode] = []
        while index < text.endIndex {
            skipWhitespace()
            if index >= text.endIndex { break }
            if text[index] == "<" && !isClosingTag() {
                if let node = parseElement() {
                    nodes.append(node)
                } else {
                    break
                }
            } else {
                break
            }
        }
        return nodes
    }

    func isClosingTag() -> Bool {
        let next = text.index(after: index)
        return next < text.endIndex && text[next] == "/"
    }

    mutating func parseElement() -> XMLNode? {
        guard index < text.endIndex, text[index] == "<" else { return nil }
        index = text.index(after: index)

        let tagName = readTagName()
        guard !tagName.isEmpty else { return nil }

        let attributes = readAttributes()

        skipWhitespace()
        guard index < text.endIndex else { return nil }

        if text[index] == "/" {
            index = text.index(after: index)
            if index < text.endIndex && text[index] == ">" {
                index = text.index(after: index)
            }
            return XMLNode(tagName: tagName, attributes: attributes, children: [], textContent: nil, isSelfClosing: true)
        }

        guard text[index] == ">" else {
            advancePast(">")
            return XMLNode(tagName: tagName, attributes: attributes, children: [], textContent: nil, isSelfClosing: true)
        }
        index = text.index(after: index)

        var children: [XMLNode] = []
        var textParts: [String] = []

        while index < text.endIndex {
            if text[index] == "<" {
                if isClosingTag() {
                    advancePast(">")
                    break
                } else if let child = parseElement() {
                    children.append(child)
                }
            } else {
                let t = readTextContent()
                if !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    textParts.append(t.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }

        let combinedText = textParts.isEmpty ? nil : textParts.joined(separator: " ")
        return XMLNode(tagName: tagName, attributes: attributes, children: children, textContent: combinedText, isSelfClosing: false)
    }

    mutating func skipWhitespace() {
        while index < text.endIndex && text[index].isWhitespace {
            index = text.index(after: index)
        }
    }

    mutating func advancePast(_ char: Character) {
        while index < text.endIndex {
            let c = text[index]
            index = text.index(after: index)
            if c == char { return }
        }
    }
}
