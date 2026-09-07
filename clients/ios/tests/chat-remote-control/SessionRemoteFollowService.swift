import Foundation
import SwiftData

@MainActor enum SessionRemoteFollowService {
    static var confirmsStopped = false
    static var refreshes = 0
    static func refresh(session: Session, context: ModelContext) async {
        refreshes += 1
        if confirmsStopped { session.remoteIsRunning = false }
    }
}
