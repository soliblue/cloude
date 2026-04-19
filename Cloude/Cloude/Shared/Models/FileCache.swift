import Foundation

struct FileCache {
    private var entries: [String: Data] = [:]
    private var accessOrder: [String] = []
    private let maxEntries = 15

    mutating func get(_ path: String) -> Data? {
        guard let data = entries[path] else { return nil }
        accessOrder.removeAll { $0 == path }
        accessOrder.append(path)
        return data
    }

    mutating func set(_ path: String, data: Data) {
        if entries[path] != nil {
            accessOrder.removeAll { $0 == path }
        } else if entries.count >= maxEntries {
            if let oldest = accessOrder.first {
                entries.removeValue(forKey: oldest)
                accessOrder.removeFirst()
            }
        }
        entries[path] = data
        accessOrder.append(path)
    }
}
