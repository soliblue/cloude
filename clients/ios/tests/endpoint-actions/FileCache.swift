import Foundation

actor FileCache {
    static let shared = FileCache()
    var removed: Set<UUID> = []
    func remove(endpoint: UUID) { removed.insert(endpoint) }
}
