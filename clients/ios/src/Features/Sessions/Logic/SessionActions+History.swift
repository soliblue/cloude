import Foundation

extension SessionActions {
    @MainActor static func setHistoryPaging(older: String?, newer: String?, for session: Session) {
        session.remoteHistoryOlderCursor = older
        session.remoteHistoryNewerCursor = newer
        session.remoteHistoryPagingScope = session.historyScopeKey
        session.remoteHistoryPagingInitialized = true
        session.remoteHistoryETag = nil
    }
}
