import Foundation

enum DaemonCapabilities {
    static let supported = [
        "codex", "codexPlugins", "codexSections", "gitMutations", "gitWorktrees", "codexCompaction", "codexReview",
        "codexShell",
        "codexTerminal", "codexActiveFork", "codexIdempotentFork", "codexAttentionBatch", "codexHistoryPages",
    ]
}
