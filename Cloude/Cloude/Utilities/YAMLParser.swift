import Foundation

enum YAMLParser {
    static func parse(_ text: String) -> Any? {
        let lines = text.components(separatedBy: "\n")
        let (result, _) = parseBlock(lines: lines, startIndex: 0, minIndent: 0)
        return result
    }

    private static func parseBlock(lines: [String], startIndex: Int, minIndent: Int) -> (Any?, Int) {
        var index = startIndex

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty || line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                index += 1
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") {
                return parseArray(lines: lines, startIndex: index, minIndent: indent(of: line))
            } else if trimmed.contains(":") {
                return parseDictionary(lines: lines, startIndex: index, minIndent: indent(of: line))
            }
            break
        }
        return (nil, index)
    }

    private static func parseDictionary(lines: [String], startIndex: Int, minIndent: Int) -> ([String: Any], Int) {
        var dict: [String: Any] = [:]
        var index = startIndex

        while index < lines.count {
            let line = lines[index]
            let lineIndent = indent(of: line)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed == "---" {
                index += 1
                continue
            }

            if lineIndent < minIndent { break }
            if lineIndent > minIndent { break }

            guard let colonRange = trimmed.range(of: ":") else {
                index += 1
                continue
            }

            let key = String(trimmed[trimmed.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let afterColon = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            if afterColon.isEmpty {
                index += 1
                if index < lines.count {
                    let nextLine = lines[index]
                    let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                    let nextIndent = indent(of: nextLine)
                    if !nextTrimmed.isEmpty && nextIndent > minIndent {
                        let (child, newIndex) = parseBlock(lines: lines, startIndex: index, minIndent: nextIndent)
                        dict[key] = child ?? ""
                        index = newIndex
                    } else {
                        dict[key] = ""
                    }
                }
            } else {
                dict[key] = parseScalar(afterColon)
                index += 1
            }
        }
        return (dict, index)
    }

    private static func parseArray(lines: [String], startIndex: Int, minIndent: Int) -> ([Any], Int) {
        var arr: [Any] = []
        var index = startIndex

        while index < lines.count {
            let line = lines[index]
            let lineIndent = indent(of: line)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                index += 1
                continue
            }

            if lineIndent < minIndent { break }
            if lineIndent > minIndent { break }

            if trimmed.hasPrefix("- ") {
                let value = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if value.contains(":") && !value.hasPrefix("\"") && !value.hasPrefix("'") {
                    let itemIndent = lineIndent + 2
                    let reconstructed = String(repeating: " ", count: itemIndent) + value
                    var subLines = [reconstructed]
                    var subIndex = index + 1
                    while subIndex < lines.count {
                        let subLine = lines[subIndex]
                        let subTrimmed = subLine.trimmingCharacters(in: .whitespaces)
                        if subTrimmed.isEmpty || subTrimmed.hasPrefix("#") {
                            subIndex += 1
                            continue
                        }
                        if indent(of: subLine) > lineIndent {
                            subLines.append(subLine)
                            subIndex += 1
                        } else {
                            break
                        }
                    }
                    let (child, _) = parseDictionary(lines: subLines, startIndex: 0, minIndent: itemIndent)
                    arr.append(child)
                    index = subIndex
                } else {
                    arr.append(parseScalar(value))
                    index += 1
                }
            } else {
                break
            }
        }
        return (arr, index)
    }

    private static func parseScalar(_ value: String) -> Any {
        if value == "true" || value == "True" || value == "yes" { return true }
        if value == "false" || value == "False" || value == "no" { return false }
        if value == "null" || value == "~" || value.isEmpty { return NSNull() }

        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
           (value.hasPrefix("'") && value.hasSuffix("'")) {
            return String(value.dropFirst().dropLast())
        }

        if let intVal = Int(value) { return NSNumber(value: intVal) }
        if let doubleVal = Double(value) { return NSNumber(value: doubleVal) }

        if value.hasPrefix("[") && value.hasSuffix("]") {
            let inner = String(value.dropFirst().dropLast())
            return inner.components(separatedBy: ",").map { parseScalar($0.trimmingCharacters(in: .whitespaces)) }
        }

        return value
    }

    private static func indent(of line: String) -> Int {
        line.prefix(while: { $0 == " " }).count
    }
}
