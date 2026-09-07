import Foundation
import SwiftData

enum SessionActions {
    @MainActor static func setContextUsage(tokens: Int?, window: Int?, for sessionId: UUID, context: ModelContext) {
        if let session = try? context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionId }))
            .first
        {
            if let tokens { session.contextTokens = tokens }
            if let window { session.contextWindow = window }
        }
    }
}
