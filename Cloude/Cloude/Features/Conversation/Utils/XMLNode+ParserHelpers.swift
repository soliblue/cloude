// XMLNode+ParserHelpers.swift

import Foundation

extension XMLBlockParser {
    mutating func readTagName() -> String {
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

    mutating func readAttributes() -> [(key: String, value: String)] {
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

    mutating func readAttrValue() -> String {
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

    mutating func readTextContent() -> String {
        var content = ""
        while index < text.endIndex && text[index] != "<" {
            content.append(text[index])
            index = text.index(after: index)
        }
        return content
    }
}
