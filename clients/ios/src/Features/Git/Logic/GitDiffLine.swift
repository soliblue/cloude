import Foundation

struct GitDiffLine: Identifiable {
    enum Kind { case added, removed, context, hunk, binary }
    let id = UUID()
    let text: String
    let kind: Kind
}

enum GitDiffParser {
    static func parse(_ diff: String) -> [GitDiffLine] {
        var lines: [GitDiffLine] = []
        for raw in diff.components(separatedBy: "\n") {
            if raw.hasPrefix("diff ") || raw.hasPrefix("index ") || raw.hasPrefix("---") || raw.hasPrefix("+++") {
                continue
            }
            if raw.hasPrefix("Binary files") {
                lines.append(GitDiffLine(text: raw, kind: .binary))
                continue
            }
            if raw.hasPrefix("@@") {
                lines.append(GitDiffLine(text: cleanHunk(raw), kind: .hunk))
                continue
            }
            if raw.hasPrefix("+") {
                lines.append(GitDiffLine(text: String(raw.dropFirst()), kind: .added))
                continue
            }
            if raw.hasPrefix("-") {
                lines.append(GitDiffLine(text: String(raw.dropFirst()), kind: .removed))
                continue
            }
            let text = raw.hasPrefix(" ") ? String(raw.dropFirst()) : raw
            lines.append(GitDiffLine(text: text, kind: .context))
        }
        return lines
    }

    private static func cleanHunk(_ raw: String) -> String {
        if let close = raw.range(of: "@@", options: [], range: raw.index(raw.startIndex, offsetBy: 2)..<raw.endIndex) {
            let header = String(raw[raw.startIndex..<close.upperBound])
            let trailing = String(raw[close.upperBound...]).trimmingCharacters(in: .whitespaces)
            let parts = header.replacingOccurrences(of: "@@", with: "").split(separator: " ")
            for part in parts where part.hasPrefix("+") {
                let span = part.dropFirst().split(separator: ",")
                if let lineNo = span.first {
                    return trailing.isEmpty ? "Line \(lineNo)" : "\(trailing) — Line \(lineNo)"
                }
            }
        }
        return raw
    }
}
