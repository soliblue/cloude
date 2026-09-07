import Foundation

nonisolated enum ChatProvider: String, CaseIterable {
    case codex
    case claude

    var displayName: String { self == .codex ? "Codex" : "Claude" }
    var symbol: String { self == .codex ? "terminal" : "sparkles" }
}
