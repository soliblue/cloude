import Foundation

nonisolated struct ChatImageGeneration {
    let status: String
    let savedPath: String?
    let result: String?
    let prompt: String?
    let failure: String?
    let limitId: String?
    let resetsAt: Date?

    init(input: [String: Any], result rawResult: String?) {
        let completed = rawResult.flatMap {
            (try? JSONSerialization.jsonObject(with: Data($0.utf8))) as? [String: Any]
        }
        let item = completed.flatMap { $0["type"] as? String == "imageGeneration" ? $0 : nil } ?? input
        status = item["status"] as? String ?? ""
        savedPath = item["savedPath"] as? String
        prompt = item["revisedPrompt"] as? String
        result = item["result"] as? String ?? (completed?["type"] as? String == "imageGeneration" ? nil : rawResult)
        let error = item["failure"] as? [String: Any]
        failure = error.map {
            $0["type"] as? String == "usageLimitExceeded"
                ? "Image generation usage limit reached."
                : $0["message"] as? String ?? $0["type"] as? String ?? "Image generation failed."
        }
        limitId = error?["limitId"] as? String
        resetsAt = ((error?["resetsAt"] as? NSNumber)?.doubleValue).flatMap {
            $0.isFinite && $0 > 0 ? Date(timeIntervalSince1970: $0) : nil
        }
    }

    var statusLabel: String {
        if failure != nil || status == "failed" { return "Image generation failed" }
        if status == "completed" { return "Generated image" }
        if status == "inProgress" || status == "in_progress" { return "Generating image" }
        return "Image generation"
    }

    func previewPath(relativeTo cwd: String?) -> String? {
        if let path = savedPath, !path.isEmpty,
            !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
            !path.hasPrefix("//"), !path.hasPrefix("~"), URL(string: path)?.scheme == nil
        {
            if path.hasPrefix("/") { return (path as NSString).standardizingPath }
            if let cwd, cwd.hasPrefix("/"), !cwd.hasPrefix("//") {
                let base = (cwd as NSString).standardizingPath
                let resolved = ((base as NSString).appendingPathComponent(path) as NSString).standardizingPath
                if resolved.hasPrefix(base == "/" ? "/" : base + "/") { return resolved }
            }
        }
        return nil
    }
}
