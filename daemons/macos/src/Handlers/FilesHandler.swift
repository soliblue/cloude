import Foundation
import UniformTypeIdentifiers

enum FilesHandler {
    private static let fileManager = FileManager.default
    private static let iso8601 = ISO8601DateFormatter()
    private static let entryKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
    ]

    static func list(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = request.query["path"] {
            let url = resolved(path)
            if let contents = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(entryKeys),
                options: [.skipsHiddenFiles]
            ) {
                let entries = contents.map { entry(for: $0) }.sorted { lhs, rhs in
                    if (lhs["isDirectory"] as? Bool ?? false) != (rhs["isDirectory"] as? Bool ?? false) {
                        return (lhs["isDirectory"] as? Bool ?? false)
                    }
                    return (lhs["name"] as? String ?? "") < (rhs["name"] as? String ?? "")
                }
                return HTTPResponse.json(200, ["path": url.path, "entries": entries])
            }
            return HTTPResponse.json(404, ["error": "not_found"])
        }
        return HTTPResponse.json(400, ["error": "missing_path"])
    }

    static func read(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = request.query["path"] {
            let url = resolved(path)
            let mime = mimeType(for: url)
            if let range = request.headers["range"] {
                return partial(url: url, range: range, contentType: mime)
            }
            if let data = try? Data(contentsOf: url) {
                return HTTPResponse(status: 200, body: data, contentType: mime)
            }
            return HTTPResponse.json(404, ["error": "not_found"])
        }
        return HTTPResponse.json(400, ["error": "missing_path"])
    }

    static func search(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let root = request.query["path"],
            let needle = request.query["query"], !needle.isEmpty
        {
            let rootURL = resolved(root)
            let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: Array(entryKeys),
                options: [.skipsHiddenFiles]
            )
            var hits: [[String: Any]] = []
            let lowered = needle.lowercased()
            while let url = enumerator?.nextObject() as? URL, hits.count < 100 {
                if url.pathComponents.contains(where: { $0 == ".git" || $0 == "node_modules" }) {
                    enumerator?.skipDescendants()
                    continue
                }
                let depth = url.pathComponents.count - rootURL.pathComponents.count
                if depth > 5 {
                    enumerator?.skipDescendants()
                    continue
                }
                if url.lastPathComponent.lowercased().contains(lowered) {
                    hits.append(entry(for: url))
                }
            }
            return HTTPResponse.json(200, ["entries": hits])
        }
        return HTTPResponse.json(400, ["error": "missing_params"])
    }

    private static func resolved(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
    }

    private static func entry(for url: URL) -> [String: Any] {
        let values = try? url.resourceValues(forKeys: entryKeys)
        let isDir = values?.isDirectory ?? false
        var dict: [String: Any] = [
            "name": url.lastPathComponent,
            "path": url.path,
            "isDirectory": isDir,
        ]
        if let size = values?.fileSize { dict["size"] = size }
        if let modified = values?.contentModificationDate {
            dict["modifiedAt"] = iso8601.string(from: modified)
        }
        if !isDir { dict["mimeType"] = mimeType(for: url) }
        return dict
    }

    private static func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension), let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }

    private static func partial(url: URL, range: String, contentType: String) -> HTTPResponse {
        if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize,
            let eq = range.firstIndex(of: "=")
        {
            let spec = range[range.index(after: eq)...]
            if let dash = spec.firstIndex(of: "-") {
                let startStr = String(spec[..<dash])
                let endStr = String(spec[spec.index(after: dash)...])
                if let start = Int(startStr) {
                    let end = Int(endStr) ?? (size - 1)
                    let clampedEnd = min(end, size - 1)
                    if start <= clampedEnd, let handle = try? FileHandle(forReadingFrom: url) {
                        if (try? handle.seek(toOffset: UInt64(start))) != nil {
                            let slice = (try? handle.read(upToCount: clampedEnd - start + 1)) ?? Data()
                            try? handle.close()
                            return HTTPResponse(
                                status: 206,
                                body: slice,
                                contentType: contentType,
                                extraHeaders: [
                                    "Content-Range": "bytes \(start)-\(clampedEnd)/\(size)",
                                    "Accept-Ranges": "bytes",
                                ]
                            )
                        }
                        try? handle.close()
                    }
                }
            }
        }
        return HTTPResponse.json(400, ["error": "bad_range"])
    }
}
