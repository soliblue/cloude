import Foundation
import SwiftData

extension SessionActions {
    @MainActor static func addWorktree(
        from source: Session, result: SessionWorktreeResult, context: ModelContext
    ) -> Session {
        let session = Session(
            endpoint: source.endpoint, path: result.path, title: result.branch, symbol: "arrow.triangle.branch")
        session.provider = source.provider
        session.model = source.model
        session.effort = source.effort
        session.permissionMode = source.permissionMode
        session.hasCustomTitle = true
        context.insert(session)
        return session
    }
}
