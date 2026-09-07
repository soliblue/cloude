import Foundation

nonisolated enum CodexReviewTarget {
    static func valid(_ value: Any?) -> Bool {
        guard let target = value as? [String: Any], let type = target["type"] as? String,
            let allowed = [
                "uncommittedChanges": ["type"], "baseBranch": ["type", "branch"],
                "commit": ["type", "sha", "title"], "custom": ["type", "instructions"],
            ][type], Set(target.keys).isSubset(of: Set(allowed))
        else { return false }
        if type == "uncommittedChanges" { return true }
        if type == "baseBranch" {
            guard let branch = target["branch"] as? String else { return false }
            return !branch.isEmpty && branch.count <= 255
                && branch.range(of: #"[\s\x00-\x1f\x7f~^:?*\[\]\\]"#, options: .regularExpression) == nil
                && !branch.hasPrefix("-") && !branch.hasPrefix("/") && !branch.hasSuffix("/")
                && !branch.contains("..") && !branch.contains("//") && !branch.contains("@{")
                && branch.split(separator: "/", omittingEmptySubsequences: false).allSatisfy {
                    !$0.hasPrefix(".") && !$0.hasSuffix(".") && !$0.hasSuffix(".lock")
                }
        }
        if type == "commit" {
            guard let sha = target["sha"] as? String,
                sha.range(of: "^[a-fA-F0-9]{4,64}$", options: .regularExpression) != nil
            else { return false }
            if target["title"] == nil || target["title"] is NSNull { return true }
            return (target["title"] as? String).map { $0.count <= 500 && !$0.contains("\0") } == true
        }
        return (target["instructions"] as? String).map {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 16000 && !$0.contains("\0")
        } == true
    }
}
