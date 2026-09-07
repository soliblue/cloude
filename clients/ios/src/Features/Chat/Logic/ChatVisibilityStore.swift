import Foundation

@MainActor enum ChatVisibilityStore {
    private(set) static var sessions: [UUID: UUID] = [:]
    private static var covered: [UUID: UUID] = [:]

    static func set(_ sessionId: UUID?, for windowId: UUID) {
        sessions[windowId] = sessionId
    }

    static func cover(_ sessionId: UUID?, for presentationId: UUID) {
        covered[presentationId] = sessionId
    }

    static func isVisible(_ sessionId: UUID) -> Bool {
        sessions.values.contains(sessionId) && !covered.values.contains(sessionId)
    }
}
