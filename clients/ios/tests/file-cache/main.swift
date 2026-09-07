import Foundation

@main
struct FileCacheTests {
    static func check(_ condition: Bool) { precondition(condition) }

    static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = FileCache(root: root)
        let first = UUID()
        let second = UUID()
        let source = root.appendingPathComponent("download")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("first version".utf8).write(to: source)
        let saved = await cache.store(source, endpoint: first, path: "/workspace/../special [a]/file.txt")
        precondition(saved != nil)
        precondition(saved!.path.hasPrefix(root.path))
        precondition(saved!.lastPathComponent == "file.txt")
        check(await cache.cached(endpoint: second, path: "/workspace/../special [a]/file.txt") == nil)
        check(await cache.data(at: saved!) == Data("first version".utf8))
        try Data("second version".utf8).write(to: source)
        let replaced = await cache.store(source, endpoint: first, path: "/workspace/../special [a]/file.txt")
        precondition(replaced == saved)
        check(await cache.data(at: saved!, limit: 6) == Data("second".utf8))
        check(await cache.size(at: saved!) == 14)
        await cache.store(Data("listing".utf8), endpoint: first, path: "/workspace/visible.json", category: "listings")
        check(await cache.cached(endpoint: first, path: "/workspace/visible.json", category: "listings") != nil)
        await cache.remove(endpoint: first)
        check(await cache.cached(endpoint: first, path: "/workspace/../special [a]/file.txt") == nil)
        check(await cache.cached(endpoint: first, path: "/workspace/visible.json", category: "listings") == nil)
        let lines = (0..<20_001).map { "line \($0)" }.joined(separator: "\n")
        let chunks = await FilePreviewTextService.chunks(Data(lines.utf8))
        precondition(chunks.count == 201)
        precondition(chunks.joined(separator: "\n") == lines)
        let unicode = await FilePreviewTextService.chunks(Data([0x68, 0x69, 0xF0, 0x9F]))
        precondition(unicode.joined().hasPrefix("hi"))
        print("PASS: atomic replacement, endpoint isolation, bounded reads, purge, 20001-line chunking and incomplete UTF-8")
    }
}
