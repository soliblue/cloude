import Foundation

actor ScheduleCache {
    static let shared = ScheduleCache()
    private let root: URL
    private let maxBytes: Int
    private let maxFiles: Int
    private var generations: [String: UUID] = [:]

    init(
        root: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AgentSchedules"), maxBytes: Int = 33_554_432, maxFiles: Int = 128
    ) {
        self.root = root
        self.maxBytes = maxBytes
        self.maxFiles = maxFiles
    }

    func prepare(endpoint: UUID, historyId: String? = nil, generation: UUID) -> Data? {
        if let url = location(endpoint: endpoint, historyId: historyId) {
            if generations.count >= 1024 { generations.removeAll() }
            generations[url.path] = generation
            return read(endpoint: endpoint, historyId: historyId)
        }
        return nil
    }

    func read(endpoint: UUID, historyId: String? = nil) -> Data? {
        if let url = location(endpoint: endpoint, historyId: historyId),
            let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
            size <= 4_194_304,
            let data = try? Data(contentsOf: url),
            (try? JSONSerialization.jsonObject(with: data)) is [String: Any]
        {
            try? FileManager.default.setAttributes([.modificationDate: Date.now], ofItemAtPath: url.path)
            return data
        }
        return nil
    }

    func store(
        _ data: Data, endpoint: UUID, historyId: String? = nil, generation: UUID, more: Bool = false
    ) {
        if !Task.isCancelled, data.count <= 4_194_304, let url = location(endpoint: endpoint, historyId: historyId),
            generations[url.path] == generation,
            var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        {
            if historyId != nil, let incoming = object["runs"] as? [[String: Any]] {
                var rows: [String: [String: Any]] = [:]
                let previous = read(endpoint: endpoint, historyId: historyId)
                    .flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] }
                if more || object["nextCursor"] is String {
                    for row in previous?["runs"] as? [[String: Any]] ?? [] {
                        if let id = row["runId"] as? String { rows[id] = row }
                    }
                }
                for row in incoming {
                    if let id = row["runId"] as? String { rows[id] = row }
                }
                object["runs"] = Array(
                    rows.values.sorted {
                        let first = $0["scheduledFor"] as? Double ?? 0
                        let second = $1["scheduledFor"] as? Double ?? 0
                        return first == second
                            ? ($0["runId"] as? String ?? "") > ($1["runId"] as? String ?? "") : first > second
                    }.prefix(100))
                if !more, (previous?["runs"] as? [Any])?.count ?? 0 > 50, object["nextCursor"] is String {
                    object["nextCursor"] = previous?["nextCursor"]
                }
            } else if let schedules = object["schedules"] as? [Any] {
                object["schedules"] = Array(schedules.prefix(100))
            } else {
                return
            }
            if let encoded = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
                encoded.count <= 4_194_304,
                (try? FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700])) != nil
            {
                try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
                #if os(iOS)
                try? encoded.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                #else
                try? encoded.write(to: url, options: .atomic)
                #endif
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
                trim()
            }
        }
    }

    func remove(endpoint: UUID) {
        let directory = root.appendingPathComponent(endpoint.uuidString)
        generations = generations.filter { !$0.key.hasPrefix(directory.path + "/") }
        try? FileManager.default.removeItem(at: directory)
    }

    private func location(endpoint: UUID, historyId: String?) -> URL? {
        if let historyId {
            if let id = UUID(uuidString: historyId) {
                return root.appendingPathComponent(endpoint.uuidString).appendingPathComponent(
                    "history-\(id.uuidString).json")
            }
            return nil
        }
        return root.appendingPathComponent(endpoint.uuidString).appendingPathComponent("schedules.json")
    }

    private func trim() {
        if let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
        {
            let files = enumerator.compactMap { $0 as? URL }.compactMap { url -> (URL, Int, Date)? in
                if let values = try? url.resourceValues(forKeys: [
                    .fileSizeKey, .contentModificationDateKey, .isRegularFileKey,
                ]),
                    values.isRegularFile == true
                {
                    return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
                }
                return nil
            }.sorted { $0.2 > $1.2 }
            var bytes = 0
            for (index, file) in files.enumerated() {
                bytes += file.1
                if index >= maxFiles || bytes > maxBytes {
                    try? FileManager.default.removeItem(at: file.0)
                    generations.removeValue(forKey: file.0.path)
                }
            }
        }
    }
}
