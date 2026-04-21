import Foundation
import UniformTypeIdentifiers

enum FilesHandler {
    private static let iso8601 = ISO8601DateFormatter()

    static func list(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = queryParam("path", from: request) {
            let url = resolved(path)
            if let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
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
        if let path = queryParam("path", from: request) {
            let url = resolved(path)
            if let data = try? Data(contentsOf: url) {
                let mime = mimeType(for: url)
                if let range = request.headers["range"] {
                    return partial(data, range: range, contentType: mime)
                }
                return HTTPResponse(status: 200, body: data, contentType: mime)
            }
            return HTTPResponse.json(404, ["error": "not_found"])
        }
        return HTTPResponse.json(400, ["error": "missing_path"])
    }

    static func search(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let root = queryParam("path", from: request),
            let needle = queryParam("query", from: request), !needle.isEmpty
        {
            let rootURL = URL(fileURLWithPath: root).standardizedFileURL
            let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
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

    private static func queryParam(_ name: String, from request: HTTPRequest) -> String? {
        let (_, query) = RouteMatcher.split(request.path)
        return query[name]
    }

    private static func resolved(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
    }

    private static func entry(for url: URL) -> [String: Any] {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
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

    private static func partial(_ data: Data, range: String, contentType: String) -> HTTPResponse {
        if let eq = range.firstIndex(of: "="),
            case let spec = range[range.index(after: eq)...],
            let dash = spec.firstIndex(of: "-")
        {
            let startStr = String(spec[..<dash])
            let endStr = String(spec[spec.index(after: dash)...])
            if let start = Int(startStr) {
                let end = Int(endStr) ?? (data.count - 1)
                let clampedEnd = min(end, data.count - 1)
                if start <= clampedEnd {
                    let slice = data.subdata(in: start..<(clampedEnd + 1))
                    return HTTPResponse(
                        status: 206,
                        body: slice,
                        contentType: contentType,
                        extraHeaders: [
                            "Content-Range": "bytes \(start)-\(clampedEnd)/\(data.count)",
                            "Accept-Ranges": "bytes",
                        ]
                    )
                }
            }
        }
        return HTTPResponse.json(400, ["error": "bad_range"])
    }
}
