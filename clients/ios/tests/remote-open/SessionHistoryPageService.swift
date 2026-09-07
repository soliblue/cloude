import Foundation
import SwiftData

enum SessionHistoryPageService {
    static var prepareResult = false
    static var beforePrepare: ((Session, [String: Any], ModelContext, Endpoint?) async -> Void)?

    static func prepareInitial(
        session: Session, metadata: [String: Any], context: ModelContext,
        transportEndpoint: Endpoint? = nil, isCurrent: () -> Bool
    ) async -> Bool {
        if let beforePrepare { await beforePrepare(session, metadata, context, transportEndpoint) }
        return prepareResult
    }
}
