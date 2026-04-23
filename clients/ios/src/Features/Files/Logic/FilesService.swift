import Foundation

enum FilesService {
    private static let decoder = JSONDecoder()

    @MainActor
    static func list(endpoint: Endpoint, session: Session, path: String) async -> FileListingDTO? {
        await decode(
            FileListingDTO.self,
            from: HTTPClient.get(
                endpoint: endpoint, path: filePath(session), query: ["path": path])
        )
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
