import Foundation

struct GitDiffLine: Identifiable {
    enum Kind { case added, removed, context, hunk, binary }
    let id = UUID()
    let text: String
    let raw: String
    let kind: Kind
    var oldLine: Int? = nil
    var newLine: Int? = nil
    var changedRange: Range<Int>? = nil
}

enum GitDiffParser {
    static func parse(_ diff: String) -> [GitDiffLine] {
        var lines: [GitDiffLine] = []
        var oldNo = 0
        var newNo = 0
        for raw in diff.components(separatedBy: "\n") {
            if raw.hasPrefix("diff ") || raw.hasPrefix("index ") || raw.hasPrefix("---") || raw.hasPrefix("+++") {
                continue
            }
            if raw.hasPrefix("Binary files") {
                lines.append(GitDiffLine(text: raw, raw: raw, kind: .binary))
                continue
            }
            if raw.hasPrefix("@@") {
                let (o, n) = hunkStarts(raw)
                oldNo = o
                newNo = n
                lines.append(GitDiffLine(text: cleanHunk(raw, newStart: n), raw: raw, kind: .hunk))
                continue
            }
            if raw.hasPrefix("+") {
                lines.append(
                    GitDiffLine(text: String(raw.dropFirst()), raw: raw, kind: .added, newLine: newNo))
                newNo += 1
                continue
            }
            if raw.hasPrefix("-") {
                lines.append(
                    GitDiffLine(text: String(raw.dropFirst()), raw: raw, kind: .removed, oldLine: oldNo))
                oldNo += 1
                continue
            }
            let text = raw.hasPrefix(" ") ? String(raw.dropFirst()) : raw
            lines.append(
                GitDiffLine(text: text, raw: raw, kind: .context, oldLine: oldNo, newLine: newNo))
            oldNo += 1
            newNo += 1
        }
        return withWordDiff(lines)
    }

    private static func withWordDiff(_ lines: [GitDiffLine]) -> [GitDiffLine] {
        var result = lines
        var index = 0
        while index < result.count {
            if result[index].kind == .removed {
                var removed: [Int] = []
                while index < result.count && result[index].kind == .removed {
                    removed.append(index)
                    index += 1
                }
                var added: [Int] = []
                var probe = index
                while probe < result.count && result[probe].kind == .added {
                    added.append(probe)
                    probe += 1
                }
                if removed.count == added.count {
                    for pair in 0..<removed.count {
                        let (oldRange, newRange) = charDiff(
                            result[removed[pair]].text, result[added[pair]].text)
                        result[removed[pair]].changedRange = oldRange
                        result[added[pair]].changedRange = newRange
                    }
                }
            } else {
                index += 1
            }
        }
        return result
    }

    private static func charDiff(_ old: String, _ new: String) -> (Range<Int>?, Range<Int>?) {
        let o = Array(old)
        let n = Array(new)
        var prefix = 0
        while prefix < o.count && prefix < n.count && o[prefix] == n[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < o.count - prefix && suffix < n.count - prefix
            && o[o.count - 1 - suffix] == n[n.count - 1 - suffix]
        {
            suffix += 1
        }
        if prefix == 0 && suffix == 0 { return (nil, nil) }
        let oldRange = prefix < o.count - suffix ? prefix..<(o.count - suffix) : nil
        let newRange = prefix < n.count - suffix ? prefix..<(n.count - suffix) : nil
        return (oldRange, newRange)
    }

    private static func hunkHeader(_ raw: String) -> Substring? {
        guard let close = raw.range(
            of: "@@", options: [], range: raw.index(raw.startIndex, offsetBy: 2)..<raw.endIndex)
        else { return nil }
        return raw[raw.index(raw.startIndex, offsetBy: 2)..<close.lowerBound]
    }

    private static func hunkStarts(_ raw: String) -> (Int, Int) {
        var old = 1
        var new = 1
        for part in (hunkHeader(raw) ?? "").split(separator: " ") {
            if part.hasPrefix("-"), let first = part.dropFirst().split(separator: ",").first {
                old = Int(first) ?? 1
            }
            if part.hasPrefix("+"), let first = part.dropFirst().split(separator: ",").first {
                new = Int(first) ?? 1
            }
        }
        return (old, new)
    }

    private static func cleanHunk(_ raw: String, newStart: Int) -> String {
        if let close = raw.range(of: "@@", options: [], range: raw.index(raw.startIndex, offsetBy: 2)..<raw.endIndex) {
            let trailing = String(raw[close.upperBound...]).trimmingCharacters(in: .whitespaces)
            return trailing.isEmpty ? "Line \(newStart)" : "\(trailing) — Line \(newStart)"
        }
        return raw
    }
}
