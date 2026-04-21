import Foundation

enum FilesService {
    @MainActor
    static func list(endpoint: Endpoint, session: Session, path: String) async -> FileListingDTO? {
        if let (data, response) = await HTTPClient.get(
            endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/files", query: ["path": path]),
            response.statusCode == 200
        {
            return try? JSONDecoder().decode(FileListingDTO.self, from: data)
        }
        return nil
    }

    @MainActor
    static func read(
        endpoint: Endpoint, session: Session, path: String, range: ClosedRange<Int>? = nil
    ) async -> Data? {
        if let (data, response) = await HTTPClient.download(
            endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/files/read", query: ["path": path],
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
        if let (data, response) = await HTTPClient.get(
            endpoint: endpoint,
            path: "/sessions/\(session.id.uuidString)/files/search",
            query: ["path": root, "query": query],
            timeout: 10),
            response.statusCode == 200
        {
            return (try? JSONDecoder().decode(FileSearchDTO.self, from: data))?.entries
        }
        return nil
    }
}
