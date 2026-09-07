import Foundation

@MainActor enum SessionActions {
    static func setHasGit(_ value: Bool, for session: Session) { session.hasGit = value }
}
