import Foundation
import CloudeShared

struct OfflineCacheService {

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

    static func saveMemories(_ sections: [MemorySection]) {
        save(CachedPayload(data: sections, cachedAt: Date()), to: "memories.json")
    }

    static func loadMemories() -> (sections: [MemorySection], cachedAt: Date)? {
        guard let payload: CachedPayload<[MemorySection]> = load(from: "memories.json") else { return nil }
        return (payload.data, payload.cachedAt)
    }

    static func savePlans(_ stages: [String: [PlanItem]]) {
        save(CachedPayload(data: stages, cachedAt: Date()), to: "plans.json")
    }

    static func loadPlans() -> (stages: [String: [PlanItem]], cachedAt: Date)? {
        guard let payload: CachedPayload<[String: [PlanItem]]> = load(from: "plans.json") else { return nil }
        return (payload.data, payload.cachedAt)
    }

    private static func save<T: Encodable>(_ value: T, to filename: String) {
        let url = cacheDir.appendingPathComponent(filename)
        if let data = try? encoder.encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func load<T: Decodable>(from filename: String) -> T? {
        let url = cacheDir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let value = try? decoder.decode(T.self, from: data) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return value
    }
}
