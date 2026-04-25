import Foundation

enum SkillsHandler {
    private static let fileManager = FileManager.default

    static func list(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = request.query["path"] {
            let user = scan(directory: home(".claude/skills"))
            let project = scan(directory: resolved(path).appendingPathComponent(".claude/skills"))
            var merged: [String: [String: String]] = [:]
            for entry in user { merged[entry["name"] ?? ""] = entry }
            for entry in project { merged[entry["name"] ?? ""] = entry }
            let entries = merged.values.sorted { ($0["name"] ?? "") < ($1["name"] ?? "") }
            return HTTPResponse.json(200, ["entries": entries])
        }
        return HTTPResponse.json(400, ["error": "missing_path"])
    }

    static func scan(directory: URL) -> [[String: String]] {
        var results: [[String: String]] = []
        if let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for url in contents {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir {
                    let skillFile = url.appendingPathComponent("SKILL.md")
                    if fileManager.fileExists(atPath: skillFile.path) {
                        results.append([
                            "name": url.lastPathComponent,
                            "description": frontmatterDescription(at: skillFile),
                        ])
                    }
                } else if url.pathExtension == "md" {
                    results.append([
                        "name": url.deletingPathExtension().lastPathComponent,
                        "description": frontmatterDescription(at: url),
                    ])
                }
            }
        }
        return results
    }

    static func home(_ relative: String) -> URL {
        URL(fileURLWithPath: ("~/\(relative)" as NSString).expandingTildeInPath).standardizedFileURL
    }

    static func resolved(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
    }

    static func frontmatterDescription(at url: URL) -> String {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        guard text.hasPrefix("---") else { return "" }
        let body = text.dropFirst(3)
        guard let end = body.range(of: "\n---") else { return "" }
        let block = body[..<end.lowerBound]
        for line in block.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0] == "description" {
                var value = parts[1]
                if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                    value = String(value.dropFirst().dropLast())
                }
                return value
            }
        }
        return ""
    }
}
