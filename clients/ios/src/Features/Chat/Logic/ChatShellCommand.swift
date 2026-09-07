import Foundation

struct ChatShellCommand {
    let rawValue: String

    var isValid: Bool {
        !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && rawValue.utf16.count <= 16_384 && !rawValue.contains("\0")
    }

    func canSend(
        provider: ChatProvider, hasReview: Bool, hasImages: Bool, hasReferences: Bool, capabilities: [String]
    ) -> Bool {
        provider == .codex && isValid && !hasReview && !hasImages && !hasReferences
            && capabilities.contains("codexShell")
    }

    var prompt: String { "Run command\n\n\(rawValue)" }
}
