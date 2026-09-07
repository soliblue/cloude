import Foundation
import SwiftData

enum ChatService {
    @MainActor static var disconnectedHosts: [String] = []
    @MainActor static var detached: Set<UUID> = []
    @MainActor static func connectionChanged(endpointId: UUID, context: ModelContext) {
        disconnectedHosts.append((try! context.fetch(FetchDescriptor<Endpoint>())).first { $0.id == endpointId }!.host)
    }
    @MainActor static func detach(sessionId: UUID) { detached.insert(sessionId) }
}
