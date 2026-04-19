import Foundation

@MainActor
struct AggregateFileCache {
    let connections: [UUID: EnvironmentConnection]

    func get(_ path: String) -> Data? {
        for conn in connections.values {
            if let data = conn.fileCache.get(path) { return data }
        }
        return nil
    }
}
