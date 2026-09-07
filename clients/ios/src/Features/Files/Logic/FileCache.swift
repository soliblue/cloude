import CryptoKit
import Foundation

actor FileCache {
    static let shared = FileCache()
    private let root: URL

    init(
        root: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent(
            "RemoteFiles")
    ) {
        self.root = root
    }

    func location(endpoint: UUID, path: String, category: String = "files") -> URL {
        root.appendingPathComponent(endpoint.uuidString)
            .appendingPathComponent(category)
            .appendingPathComponent(SHA256.hash(data: Data(path.utf8)).map { String(format: "%02x", $0) }.joined())
            .appendingPathComponent(URL(fileURLWithPath: path).lastPathComponent)
    }

    func cached(endpoint: UUID, path: String, category: String = "files") -> URL? {
        let url = location(endpoint: endpoint, path: path, category: category)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func store(_ source: URL, endpoint: UUID, path: String) -> URL? {
        let destination = location(endpoint: endpoint, path: path)
        if (try? FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)) != nil
        {
            if FileManager.default.fileExists(atPath: destination.path) {
                if (try? FileManager.default.replaceItemAt(destination, withItemAt: source)) != nil {
                    return destination
                }
            } else if (try? FileManager.default.moveItem(at: source, to: destination)) != nil {
                return destination
            }
        }
        try? FileManager.default.removeItem(at: source)
        return nil
    }

    func store(_ data: Data, endpoint: UUID, path: String, category: String) {
        let destination = location(endpoint: endpoint, path: path, category: category)
        if (try? FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)) != nil
        {
            try? data.write(to: destination, options: .atomic)
        }
    }

    func data(at url: URL, limit: Int = 1_048_576) -> Data? {
        if let file = try? FileHandle(forReadingFrom: url) {
            defer { try? file.close() }
            return try? file.read(upToCount: limit)
        }
        return nil
    }

    func size(at url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    func remove(endpoint: UUID) {
        try? FileManager.default.removeItem(at: root.appendingPathComponent(endpoint.uuidString))
    }
}
