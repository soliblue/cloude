// XMLNode.swift

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
