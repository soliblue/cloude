import Foundation

enum GitService {
    struct DiffResult {
        let text: String
        let truncatedFromLines: Int?
    }

    @MainActor
    static func status(endpoint: Endpoint, session: Session, path: String) async -> (GitStatusDTO?, Int) {
        if let (data, response) = await HTTPClient.get(
            endpoint: endpoint,
            path: "/sessions/\(session.id.uuidString)/git/status",
            query: ["path": path]
        ) {
            if response.statusCode == 200 {
                return ((try? JSONDecoder().decode(GitStatusDTO.self, from: data)), 200)
            }
            return (nil, response.statusCode)
        }
        return (nil, -1)
    }

    @MainActor
    static func diff(
        endpoint: Endpoint,
        session: Session,
        path: String,
        file: String,
        isStaged: Bool,
        isFull: Bool = false
    ) async -> DiffResult? {
        var query: [String: String] = [
            "path": path,
            "file": file,
            "staged": isStaged ? "1" : "0",
        ]
        if isFull { query["full"] = "1" }
        if let (data, response) = await HTTPClient.get(
            endpoint: endpoint,
            path: "/sessions/\(session.id.uuidString)/git/diff",
            query: query,
            timeout: 10
        ),
            response.statusCode == 200
        {
            let text = String(data: data, encoding: .utf8) ?? ""
            let truncated = (response.value(forHTTPHeaderField: "X-Diff-Truncated")).flatMap(Int.init)
            return DiffResult(text: text, truncatedFromLines: truncated)
        }
        return nil
    }

    @MainActor
    static func log(
        endpoint: Endpoint, session: Session, path: String, skip: Int = 0, count: Int = 50
    ) async -> [GitCommitDTO]? {
        if let (data, response) = await HTTPClient.get(
            endpoint: endpoint,
            path: "/sessions/\(session.id.uuidString)/git/log",
            query: ["path": path, "skip": String(skip), "count": String(count)]
        ),
            response.statusCode == 200
        {
            return (try? JSONDecoder().decode(GitLogDTO.self, from: data))?.commits
        }
        return nil
    }
}
