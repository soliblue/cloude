import Foundation

enum WindowsSidebarSection: String, CaseIterable, Identifiable {
    case attention = "Needs attention"
    case running = "Working"
    case pinned = "Pinned"
    case recent = "Recent"

    var id: String { rawValue }

    func sessions(from sessions: [Session], search: String) -> [Session] {
        sessions.filter { session in
            !session.isArchived
                && (search.isEmpty
                    || [session.title, session.path ?? "", session.endpoint?.displayName ?? ""]
                        .contains { $0.localizedCaseInsensitiveContains(search) })
                && Self.section(for: session) == self
        }
    }

    static func section(for session: Session) -> WindowsSidebarSection {
        if session.needsAttention || session.hasUnread { return .attention }
        if session.isStreaming || session.remoteIsRunning { return .running }
        return session.isPinned ? .pinned : .recent
    }
}
