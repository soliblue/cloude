import Foundation

struct GitDiffLine: Identifiable {
    enum Kind { case added, removed, context, hunk, binary }
    let id = UUID()
    let text: String
    let raw: String
    let kind: Kind
    var oldLine: Int? = nil
    var newLine: Int? = nil
}

enum GitDiffParser {
    struct FileDiff: Identifiable {
        let path: String
        let text: String
        var id: String { path }
    }

    struct DiffHunk: Identifiable {
        let id: String
        let header: String
        let lines: [GitDiffLine]
        let additions: Int
        let deletions: Int
    }

    static func groupHunks(_ lines: [GitDiffLine], filePath: String) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        var header = ""
        var body: [GitDiffLine] = []
        var index = 0
        func flush() {
            let keep = !header.isEmpty || body.contains { $0.kind != .context }
            if keep {
                hunks.append(
                    DiffHunk(
                        id: "\(filePath)#\(index)", header: header, lines: body,
                        additions: body.filter { $0.kind == .added }.count,
                        deletions: body.filter { $0.kind == .removed }.count))
                index += 1
            }
        }
        for line in lines {
            if line.kind == .hunk {
                flush()
                header = line.text
                body = []
            } else {
                body.append(line)
            }
        }
        flush()
        return hunks
    }

    static func splitByFile(_ diff: String) -> [FileDiff] {
        var files: [FileDiff] = []
        var currentPath: String?
        var current: [String] = []
        var sawHunk = false
        func flush() {
            while current.last == "" { current.removeLast() }
            if let path = currentPath, !current.isEmpty {
                files.append(FileDiff(path: path, text: current.joined(separator: "\n")))
            }
        }
        for raw in diff.components(separatedBy: "\n") {
            if raw.hasPrefix("diff --git ") {
                flush()
                current = [raw]
                currentPath = headerPath(raw)
                sawHunk = false
                continue
            }
            if currentPath == nil { continue }
            if raw.hasPrefix("@@") { sawHunk = true }
            if !sawHunk && raw.hasPrefix("+++ b/") {
                currentPath = String(raw.dropFirst(6))
            }
            current.append(raw)
        }
        flush()
        return files
    }

    private static func headerPath(_ raw: String) -> String {
        if let range = raw.range(of: " b/", options: .backwards) {
            return String(raw[range.upperBound...])
        }
        return "file"
    }

    static func parse(_ diff: String) -> [GitDiffLine] {
        var lines: [GitDiffLine] = []
        var oldNo: Int? = nil
        var newNo: Int? = nil
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
                if newNo != nil { newNo! += 1 }
                continue
            }
            if raw.hasPrefix("-") {
                lines.append(
                    GitDiffLine(text: String(raw.dropFirst()), raw: raw, kind: .removed, oldLine: oldNo))
                if oldNo != nil { oldNo! += 1 }
                continue
            }
            let text = raw.hasPrefix(" ") ? String(raw.dropFirst()) : raw
            lines.append(
                GitDiffLine(text: text, raw: raw, kind: .context, oldLine: oldNo, newLine: newNo))
            if oldNo != nil { oldNo! += 1 }
            if newNo != nil { newNo! += 1 }
        }
        return lines
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
