import Foundation

enum SessionProjectService {
    @MainActor static var removed: Set<UUID> = []
    @MainActor static func removeCache(endpointId: UUID) async { removed.insert(endpointId) }
}
