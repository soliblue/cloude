import Foundation
import CloudeShared

struct PlansService {
    static let stages = ["active", "testing", "next", "backlog"]

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
                let title = extractTitle(from: content) ?? filename.replacingOccurrences(of: ".md", with: "")
                return PlanItem(filename: filename, title: title, content: content, path: filePath)
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
}
