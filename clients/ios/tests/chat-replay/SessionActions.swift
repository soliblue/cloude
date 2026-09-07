import Foundation
import SwiftData

enum SessionActions {
    static func setLastSeq(_ value: Int, for session: Session) { session.lastSeq = value }
    static func setRemoteRunning(_ value: Bool, for session: Session) { session.remoteIsRunning = value }
    static func setRemoteTurnStatus(_ value: String?, for session: Session) { session.remoteTurnStatus = value }
    static func setContextUsage(tokens: Int?, window: Int?, for sessionId: UUID, context: ModelContext) {}
}
