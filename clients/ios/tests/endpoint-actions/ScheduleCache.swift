import Foundation

actor ScheduleCache {
    static let shared = ScheduleCache()
    var removed: Set<UUID> = []
    func remove(endpoint: UUID) { removed.insert(endpoint) }
}
