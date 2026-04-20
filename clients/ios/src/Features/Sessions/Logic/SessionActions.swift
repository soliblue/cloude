import Foundation
import SwiftData

enum SessionActions {
    @MainActor
    static func add(into context: ModelContext) -> Session {
        let session = Session()
        context.insert(session)
        return session
    }
}
