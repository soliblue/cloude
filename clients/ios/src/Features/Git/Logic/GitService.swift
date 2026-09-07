import Foundation
import SwiftData

@MainActor enum GitService {
    @concurrent
    static func parseDiff(_ text: String) async -> [GitDiffLine] { GitDiffParser.parse(text) }

    struct DiffResult {
        let text: String
        let truncatedFromLines: Int?
    }

    @MainActor
    static func status(endpoint: Endpoint, session: Session, path: String) async -> (GitStatusDTO?, Int) {
        if let (data, response) = await HTTPClient.get(
            endpoint: endpoint,
            path: "/sessions/\(session.id.uuidString)/git/status",
            query: ["path": path],
            timeout: 10
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
    static func commitDetail(
        endpoint: Endpoint, session: Session, path: String, sha: String
    ) async -> GitCommitDetailDTO? {
        if let (data, response) = await HTTPClient.get(
            endpoint: endpoint,
            path: "/sessions/\(session.id.uuidString)/git/commit",
            query: ["path": path, "sha": sha],
            timeout: 10
        ),
            response.statusCode == 200
        {
            return try? JSONDecoder().decode(GitCommitDetailDTO.self, from: data)
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
            query: ["path": path, "skip": String(skip), "count": String(count)],
            timeout: 10
        ),
            response.statusCode == 200
        {
            return (try? JSONDecoder().decode(GitLogDTO.self, from: data))?.commits
        }
        return nil
    }

    @MainActor private static var refreshTasks: [UUID: Task<Void, Never>] = [:]
    @MainActor private static var pendingRefresh: Set<UUID> = []

    static func loadMore(session: Session, count: Int, context: ModelContext) async -> Int? {
        if let endpoint = session.endpoint, let path = session.path {
            let endpointId = endpoint.id
            let cacheId = endpoint.cacheId
            if let commits = await log(endpoint: endpoint, session: session, path: path, skip: count),
                session.endpoint?.id == endpointId, session.endpoint?.cacheId == cacheId, session.path == path,
                !Task.isCancelled
            {
                GitActions.replaceLog(sessionId: session.id, commits: commits, context: context, append: true)
                return commits.count
            }
        }
        return nil
    }

    @MainActor
    static func refresh(session: Session, context: ModelContext) async {
        if let task = refreshTasks[session.id] {
            pendingRefresh.insert(session.id)
            await task.value
        } else {
            let sessionId = session.id
            let task = Task {
                repeat {
                    await refreshOnce(session: session, context: context)
                } while pendingRefresh.remove(sessionId) != nil
                refreshTasks.removeValue(forKey: sessionId)
            }
            refreshTasks[sessionId] = task
            await task.value
        }
    }

    @MainActor
    private static func refreshOnce(session: Session, context: ModelContext) async {
        if let endpoint = session.endpoint, let path = session.path {
            let endpointId = endpoint.id
            let cacheId = endpoint.cacheId
            async let statusResult = status(endpoint: endpoint, session: session, path: path)
            async let logResult = log(endpoint: endpoint, session: session, path: path)
            let (dto, code) = await statusResult
            let commits = await logResult
            if session.endpoint?.id == endpointId, session.endpoint?.cacheId == cacheId, session.path == path {
                if code == 404 {
                    SessionActions.setHasGit(false, for: session)
                    GitActions.clear(sessionId: session.id, context: context)
                } else if let dto {
                    SessionActions.setHasGit(true, for: session)
                    GitActions.upsertStatus(sessionId: session.id, dto: dto, context: context)
                    if let commits {
                        GitActions.replaceLog(sessionId: session.id, commits: commits, context: context)
                    }
                }
            }
        }
    }
}
