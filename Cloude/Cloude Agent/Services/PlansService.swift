import Foundation
import CloudeShared

struct PlansService {
    static let stages = ["backlog", "next", "active", "testing", "done"]

    static func readPlans(workingDirectory: String) -> [String: [PlanItem]] {
        let plansDir = (workingDirectory as NSString).appendingPathComponent("plans")
        let fm = FileManager.default
        var result: [String: [PlanItem]] = [:]

        for stage in stages {
            let stageDir = (plansDir as NSString).appendingPathComponent(stage)
            guard let files = try? fm.contentsOfDirectory(atPath: stageDir) else {
                result[stage] = []
                continue
            }

            let plans = files.filter { $0.hasSuffix(".md") }.sorted().compactMap { filename -> PlanItem? in
                let filePath = (stageDir as NSString).appendingPathComponent(filename)
                guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { return nil }
                let rawTitle = extractTitle(from: content) ?? filename.replacingOccurrences(of: ".md", with: "")
                let (title, icon) = extractIcon(from: rawTitle)
                let description = extractDescription(from: content)
                return PlanItem(filename: filename, title: title, icon: icon, description: description, content: content, path: filePath)
            }

            result[stage] = plans
        }

        return result
    }

    static func deletePlan(stage: String, filename: String, workingDirectory: String) {
        guard stages.contains(stage) else { return }
        guard !filename.contains("/") && !filename.contains("..") else { return }
        let path = (workingDirectory as NSString)
            .appendingPathComponent("plans")
            .appending("/\(stage)/\(filename)")
        try? FileManager.default.removeItem(atPath: path)
    }

    private static func extractTitle(from content: String) -> String? {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2))
            }
        }
        return nil
    }

    private static func extractDescription(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        var pastHeading = false
        var quoteLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !pastHeading {
                if trimmed.hasPrefix("# ") { pastHeading = true }
                continue
            }
            if trimmed.isEmpty && quoteLines.isEmpty { continue }
            if trimmed.hasPrefix("> ") {
                quoteLines.append(String(trimmed.dropFirst(2)))
            } else {
                break
            }
        }

        let result = quoteLines.prefix(3).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    private static func extractIcon(from title: String) -> (String, String?) {
        let pattern = "^(.+?)\\s*\\{([a-z0-9.]+)\\}$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) {
            let titleRange = Range(match.range(at: 1), in: title)!
            let iconRange = Range(match.range(at: 2), in: title)!
            return (String(title[titleRange]).trimmingCharacters(in: .whitespaces), String(title[iconRange]))
        }
        return (title, nil)
    }
}
