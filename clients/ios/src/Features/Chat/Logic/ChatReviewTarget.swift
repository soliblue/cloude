import Foundation

nonisolated struct ChatReviewTarget: Codable, Equatable {
    let type: ChatReviewKind
    var branch: String? = nil
    var sha: String? = nil
    var title: String? = nil
    var instructions: String? = nil

    var isValid: Bool {
        switch type {
        case .uncommittedChanges: true
        case .baseBranch:
            branch.map {
                !$0.isEmpty && !$0.hasPrefix("-") && !$0.contains(where: \.isWhitespace) && !$0.contains("\0")
            } ?? false
        case .commit:
            sha.map {
                (4...64).contains($0.count)
                    && $0.utf8.allSatisfy {
                        (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
                    }
            } ?? false
        case .custom:
            instructions.map {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 20000 && !$0.contains("\0")
            } ?? false
        }
    }

    var parameters: [String: Any] {
        var body: [String: Any] = ["type": type.rawValue]
        switch type {
        case .uncommittedChanges: break
        case .baseBranch: body["branch"] = branch
        case .commit:
            body["sha"] = sha
            if let title { body["title"] = title }
        case .custom: body["instructions"] = instructions
        }
        return body
    }

    var prompt: String {
        switch type {
        case .uncommittedChanges: "Review my uncommitted changes, including staged, unstaged and untracked files."
        case .baseBranch: "Review the current branch against \(branch ?? "")."
        case .commit: "Review commit \(sha ?? "")."
        case .custom: "Review code with these instructions:\n\n\(instructions ?? "")"
        }
    }
}
