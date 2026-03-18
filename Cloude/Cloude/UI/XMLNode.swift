import Foundation

struct XMLNode: Identifiable {
    let id = UUID()
    let tagName: String
    var attributes: [(key: String, value: String)]
    var children: [XMLNode]
    var textContent: String?
    var isSelfClosing: Bool

    static func parse(_ raw: String) -> [XMLNode] {
        var parser = XMLBlockParser(raw)
        return parser.parseNodes()
    }

    func toXMLString(depth: Int) -> String {
        let indent = String(repeating: "  ", count: depth)
        let attrs = attributes.map { " \($0.key)=\"\($0.value)\"" }.joined()

        if isSelfClosing {
            return "\(indent)<\(tagName)\(attrs) />"
        }

        if children.isEmpty {
            let text = textContent ?? ""
            return "\(indent)<\(tagName)\(attrs)>\(text)</\(tagName)>"
        }

        var lines = ["\(indent)<\(tagName)\(attrs)>"]
        if let text = textContent {
            lines.append("\(indent)  \(text)")
        }
        for child in children {
            lines.append(child.toXMLString(depth: depth + 1))
        }
        lines.append("\(indent)</\(tagName)>")
        return lines.joined(separator: "\n")
    }
}

private struct XMLBlockParser {
    private let text: String
    private var index: String.Index

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

    private func isClosingTag() -> Bool {
        let next = text.index(after: index)
        return next < text.endIndex && text[next] == "/"
    }

    private mutating func parseElement() -> XMLNode? {
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

    private mutating func readTagName() -> String {
        var name = ""
        while index < text.endIndex {
            let c = text[index]
            if c.isLetter || c.isNumber || c == "_" || c == "-" || c == ":" || c == "." {
                name.append(c)
                index = text.index(after: index)
            } else {
                break
            }
        }
        return name
    }

    private mutating func readAttributes() -> [(key: String, value: String)] {
        var attrs: [(String, String)] = []
        while index < text.endIndex {
            skipWhitespace()
            if index >= text.endIndex { break }
            let c = text[index]
            if c == ">" || c == "/" { break }

            let key = readTagName()
            if key.isEmpty { index = text.index(after: index); continue }

            skipWhitespace()
            if index < text.endIndex && text[index] == "=" {
                index = text.index(after: index)
                skipWhitespace()
                let value = readAttrValue()
                attrs.append((key, value))
            } else {
                attrs.append((key, ""))
            }
        }
        return attrs
    }

    private mutating func readAttrValue() -> String {
        guard index < text.endIndex else { return "" }
        let quote = text[index]
        if quote == "\"" || quote == "'" {
            index = text.index(after: index)
            var value = ""
            while index < text.endIndex && text[index] != quote {
                value.append(text[index])
                index = text.index(after: index)
            }
            if index < text.endIndex { index = text.index(after: index) }
            return value
        }
        var value = ""
        while index < text.endIndex && !text[index].isWhitespace && text[index] != ">" && text[index] != "/" {
            value.append(text[index])
            index = text.index(after: index)
        }
        return value
    }

    private mutating func readTextContent() -> String {
        var content = ""
        while index < text.endIndex && text[index] != "<" {
            content.append(text[index])
            index = text.index(after: index)
        }
        return content
    }

    private mutating func skipWhitespace() {
        while index < text.endIndex && text[index].isWhitespace {
            index = text.index(after: index)
        }
    }

    private mutating func advancePast(_ char: Character) {
        while index < text.endIndex {
            let c = text[index]
            index = text.index(after: index)
            if c == char { return }
        }
    }
}
