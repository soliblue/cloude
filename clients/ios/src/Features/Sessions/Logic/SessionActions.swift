import Foundation
import SwiftData

enum SessionActions {
    @MainActor
    static func add(into context: ModelContext) -> Session {
        let session = Session()
        context.insert(session)
        return session
    }

    @MainActor
    static func setEndpoint(_ endpoint: Endpoint, for session: Session) {
        session.endpoint = endpoint
    }

    @MainActor
    static func setPath(_ path: String, for session: Session) {
        session.path = path
    }

    @MainActor
    static func markExistsOnServer(_ session: Session) {
        session.existsOnServer = true
    }

    @MainActor
    static func setTab(_ tab: SessionTab, for session: Session) {
        session.tab = tab
    }
}
