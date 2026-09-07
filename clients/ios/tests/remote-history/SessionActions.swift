import Foundation

enum SessionActions {
    static func setRemoteHistoryETag(_ value: String?, for session: Session) { session.remoteHistoryETag = value }
    static func setGoal(_ goal: ChatGoal?, for session: Session) {
        session.goalData = goal.flatMap { try? JSONEncoder().encode($0) }
    }
    static func setRemoteTurnStatus(_ value: String?, for session: Session) { session.remoteTurnStatus = value }
    static func refreshRemoteTitle(_ thread: SessionRemoteThread, for session: Session) {
        if !session.hasCustomTitle, thread.title != "Untitled Codex chat" { session.title = thread.title }
    }
    static func setRemoteRunning(_ value: Bool, for session: Session) { session.remoteIsRunning = value }
}
