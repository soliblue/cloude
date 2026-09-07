import Foundation

enum FilesService {
    private static let decoder = JSONDecoder()

    @MainActor
    static func list(
        endpoint: Endpoint, session: Session, path: String, showHidden: Bool = false
    ) async -> FileListingDTO? {
        let cacheId = endpoint.cacheId
        var query = ["path": path]
        if showHidden { query["showHidden"] = "true" }
        let cacheKey = "\(path)/\(showHidden ? "all" : "visible").json"
        if let (data, response) = await HTTPClient.get(endpoint: endpoint, path: filePath(session), query: query) {
            if endpoint.cacheId == cacheId, !Task.isCancelled, response.statusCode == 200,
                let listing = try? decoder.decode(FileListingDTO.self, from: data)
            {
                await FileCache.shared.store(data, endpoint: cacheId, path: cacheKey, category: "listings")
                return listing
            }
        } else if !Task.isCancelled, endpoint.cacheId == cacheId,
            let url = await FileCache.shared.cached(endpoint: cacheId, path: cacheKey, category: "listings"),
            let data = await FileCache.shared.data(at: url, limit: 16_777_216)
        {
            return try? decoder.decode(FileListingDTO.self, from: data)
        }
        return nil
    }

    @MainActor
    static func read(
        endpoint: Endpoint, session: Session, path: String, range: ClosedRange<Int>? = nil
    ) async -> Data? {
        if let (data, response) = await HTTPClient.download(
            endpoint: endpoint, path: filePath(session, "read"), query: ["path": path],
            range: range),
            response.statusCode == 200 || response.statusCode == 206
        {
            return data
        }
        return nil
    }

    @MainActor
    static func search(
        endpoint: Endpoint, session: Session, root: String, query: String
    ) async -> [FileNodeDTO]? {
        await decode(
            FileSearchDTO.self,
            from: HTTPClient.get(
                endpoint: endpoint,
                path: filePath(session, "search"),
                query: ["path": root, "query": query],
                timeout: 10)
        )?.entries
    }

    private static func filePath(_ session: Session, _ suffix: String? = nil) -> String {
        if let suffix { return "/sessions/\(session.id.uuidString)/files/\(suffix)" }
        return "/sessions/\(session.id.uuidString)/files"
    }

    private static func decode<T: Decodable>(
        _ type: T.Type, from result: (Data, HTTPURLResponse)?
    ) -> T? {
        if let (data, response) = result, response.statusCode == 200 {
            return try? decoder.decode(type, from: data)
        }
        return nil
    }
}
