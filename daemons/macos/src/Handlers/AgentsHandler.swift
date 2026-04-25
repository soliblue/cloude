import Foundation

enum AgentsHandler {
    private static let fileManager = FileManager.default

    static func list(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = request.query["path"] {
            let user = scan(directory: SkillsHandler.home(".claude/agents"))
            let project = scan(directory: SkillsHandler.resolved(path).appendingPathComponent(".claude/agents"))
            var merged: [String: [String: String]] = [:]
            for entry in user { merged[entry["name"] ?? ""] = entry }
            for entry in project { merged[entry["name"] ?? ""] = entry }
            let entries = merged.values.sorted { ($0["name"] ?? "") < ($1["name"] ?? "") }
            return HTTPResponse.json(200, ["entries": entries])
        }
        return HTTPResponse.json(400, ["error": "missing_path"])
    }

    private static func scan(directory: URL) -> [[String: String]] {
        var results: [[String: String]] = []
        if let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for url in contents where url.pathExtension == "md" {
                results.append([
                    "name": url.deletingPathExtension().lastPathComponent,
                    "description": SkillsHandler.frontmatterDescription(at: url),
                ])
            }
        }
        return results
    }
}
