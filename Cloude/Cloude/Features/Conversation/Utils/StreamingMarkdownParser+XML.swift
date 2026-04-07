import Foundation

extension StreamingMarkdownParser {
    static func looksLikeXMLBlock(_ line: String) -> Bool {
        guard line.hasPrefix("<") else { return false }
        let xmlTagPattern = #"^</?[a-zA-Z][a-zA-Z0-9_:.-]*[\s/>]"#
        return line.range(of: xmlTagPattern, options: .regularExpression) != nil
    }

    static func parseXMLBlock(lines: [String], index i: inout Int) -> StreamingBlock? {
        let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
        guard looksLikeXMLBlock(trimmed) else { return nil }

        let startLine = i
        let savedIndex = i
        var xmlLines: [String] = []

        if trimmed.hasSuffix("/>") || isSelfClosingOneLine(trimmed) {
            xmlLines.append(lines[i])
            i += 1
        } else {
            let tagName = extractOpeningTagName(trimmed)
            guard let tagName, !tagName.isEmpty else { return nil }

            var depth = 0
            while i < lines.count {
                let l = lines[i]
                xmlLines.append(l)

                depth += countOpens(l, tag: tagName) - countCloses(l, tag: tagName)
                i += 1

                if depth <= 0 { break }
            }
        }

        let raw = xmlLines.joined(separator: "\n")
        let nodes = XMLNode.parse(raw)
        if nodes.isEmpty {
            i = savedIndex
            return nil
        }
        return .xml(id: "xml-L\(startLine)", nodes: nodes)
    }

    private static func isSelfClosingOneLine(_ line: String) -> Bool {
        guard let tagName = extractOpeningTagName(line) else { return false }
        return line.contains("</\(tagName)>")
    }

    private static func extractOpeningTagName(_ line: String) -> String? {
        guard line.hasPrefix("<") else { return nil }
        let afterBracket = line.dropFirst()
        var name = ""
        for c in afterBracket {
            if c.isLetter || c.isNumber || c == "_" || c == "-" || c == ":" || c == "." {
                name.append(c)
            } else {
                break
            }
        }
        return name.isEmpty ? nil : name
    }

    private static func countOpens(_ line: String, tag: String) -> Int {
        var count = 0
        var search = line[...]
        let pattern = "<\(tag)"
        while let range = search.range(of: pattern) {
            let afterTag = range.upperBound < search.endIndex ? search[range.upperBound] : Character(">")
            if afterTag == " " || afterTag == ">" || afterTag == "/" {
                count += 1
            }
            search = search[range.upperBound...]
        }
        return count
    }

    private static func countCloses(_ line: String, tag: String) -> Int {
        var count = 0
        var search = line[...]
        let pattern = "</\(tag)>"
        while let range = search.range(of: pattern) {
            count += 1
            search = search[range.upperBound...]
        }
        return count
    }
}
