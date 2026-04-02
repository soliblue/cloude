import Foundation
import CloudeShared

struct MemoriesCache {
    private static let cacheDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private struct CachedPayload<T: Codable>: Codable {
        let data: T
        let cachedAt: Date
    }

    static func save(_ sections: [MemorySection]) {
        let url = cacheDir.appendingPathComponent("memories.json")
        if let data = try? encoder.encode(CachedPayload(data: sections, cachedAt: Date())) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func load() -> (sections: [MemorySection], cachedAt: Date)? {
        let url = cacheDir.appendingPathComponent("memories.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let payload = try? decoder.decode(CachedPayload<[MemorySection]>.self, from: data) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return (payload.data, payload.cachedAt)
    }
}
