import Foundation
import Observation

@MainActor @Observable final class SessionReviewStore {
    var kind = ChatReviewKind.uncommittedChanges
    var sha = ""
    var instructions = ""
    var error: String?
    var branches = SessionWorktreeStore()

    var target: ChatReviewTarget {
        switch kind {
        case .uncommittedChanges: ChatReviewTarget(type: .uncommittedChanges)
        case .baseBranch: ChatReviewTarget(type: .baseBranch, branch: branches.baseRef)
        case .commit: ChatReviewTarget(type: .commit, sha: sha.trimmingCharacters(in: .whitespacesAndNewlines))
        case .custom:
            ChatReviewTarget(type: .custom, instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func canRun(session: Session) -> Bool {
        session.provider == .codex && session.isConfigured && !session.isStreaming && !session.remoteIsRunning
            && session.endpoint?.capabilities?.contains("codexReview") == true && target.isValid
            && (kind != .baseBranch
                || (!branches.isLoading && branches.branches.contains { $0.name == branches.baseRef }))
    }
}
