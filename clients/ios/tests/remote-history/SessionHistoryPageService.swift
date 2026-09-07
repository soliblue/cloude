import Foundation
import SwiftData

enum SessionHistoryPageService {
    static func refresh(session: Session, context: ModelContext) async {
        preconditionFailure("Legacy history fixture must use the full-history path")
    }
}
