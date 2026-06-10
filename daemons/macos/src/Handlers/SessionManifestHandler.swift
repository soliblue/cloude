import Foundation

enum SessionManifestHandler {
    static func manifest(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = request.query["path"] {
            let root = (path as NSString).expandingTildeInPath
            let home = NSHomeDirectory()
            return HTTPResponse.json(200, [
                "skills": merged([skills(in: "\(root)/.claude"), skills(in: "\(home)/.claude")]),
                "agents": merged([agents(in: "\(root)/.claude"), agents(in: "\(home)/.claude")]),
                "transcription": false,
            ])
        }
        return HTTPResponse.json(400, ["error": "missing_path"])
    }

    private static func merged(_ lists: [[[String: String]]]) -> [[String: String]] {
        var seen: Set<String> = []
        var result: [[String: String]] = []
        for list in lists {
            for item in list where item["name"].map({ !seen.contains($0) }) ?? false {
                seen.insert(item["name"] ?? "")
                result.append(item)
            }
        }
        return result
    }

    private static func skills(in base: String) -> [[String: String]] {
        let dir = "\(base)/skills"
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return [] }
        var result: [[String: String]] = []
        for entry in entries.sorted() {
            let full = "\(dir)/\(entry)"
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            let file = isDir.boolValue ? "\(full)/SKILL.md" : full
            if isDir.boolValue || entry.hasSuffix(".md"),
                let content = try? String(contentsOfFile: file, encoding: .utf8)
            {
                let meta = frontmatter(content)
                if let name = meta["name"], let description = meta["description"],
                    meta["user-invocable"] != "false"
                {
                    result.append([
                        "name": name,
                        "description": description,
                        "icon": meta["icon"] ?? "hammer.circle",
                    ])
                }
            }
        }
        return result
    }

    private static func agents(in base: String) -> [[String: String]] {
        let dir = "\(base)/agents"
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return [] }
        var result: [[String: String]] = []
        for entry in entries.sorted() where entry.hasSuffix(".md") {
            if let content = try? String(contentsOfFile: "\(dir)/\(entry)", encoding: .utf8) {
                let meta = frontmatter(content)
                if let name = meta["name"], let description = meta["description"] {
                    result.append(["name": name, "description": description])
                }
            }
        }
        return result
    }

    private static func frontmatter(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        var started = false
        var inMetadata = false
        for line in content.components(separatedBy: "\n") {
            if line == "---" {
                if started { break }
                started = true
                continue
            }
            if !started { continue }
            if line.hasPrefix("  ") {
                if inMetadata, let pair = keyValue(line.trimmingCharacters(in: .whitespaces)) {
                    result[pair.0] = pair.1
                }
                continue
            }
            inMetadata = false
            if let pair = keyValue(line) {
                if pair.0 == "metadata", pair.1.isEmpty {
                    inMetadata = true
                } else {
                    result[pair.0] = pair.1
                }
            }
        }
        return result
    }

    private static func keyValue(_ line: String) -> (String, String)? {
        if let colon = line.firstIndex(of: ":") {
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            if !key.isEmpty { return (key, value) }
        }
        return nil
    }
}
