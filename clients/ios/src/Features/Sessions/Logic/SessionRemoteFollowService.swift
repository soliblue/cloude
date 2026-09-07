import Foundation
import SwiftData

@MainActor
enum SessionRemoteFollowService {
    private static var tasks: [UUID: (id: UUID, task: Task<Void, Never>)] = [:]
    private static var refreshingRunning = false

    static func detach(sessionId: UUID) {
        tasks.removeValue(forKey: sessionId)?.task.cancel()
    }

    static func refreshRunning(context: ModelContext) async {
        if !refreshingRunning {
            refreshingRunning = true
            defer { refreshingRunning = false }
            let sessions =
                (try? context.fetch(
                    FetchDescriptor<Session>(
                        predicate: #Predicate<Session> { $0.followsRemote && $0.remoteIsRunning && !$0.isStreaming }
                    ))) ?? []
            for start in stride(from: 0, to: sessions.count, by: 3) {
                if Task.isCancelled { break }
                let batch = sessions[start..<min(start + 3, sessions.count)].map { session in
                    Task { await refresh(session: session, context: context) }
                }
                await withTaskCancellationHandler {
                    for task in batch { await task.value }
                } onCancel: {
                    for task in batch { task.cancel() }
                }
            }
        }
    }

    static func refresh(session: Session, context: ModelContext) async {
        if let existing = tasks[session.id] {
            await existing.task.value
        } else {
            let id = UUID()
            let task = Task { await load(session: session, context: context) }
            tasks[session.id] = (id, task)
            await withTaskCancellationHandler {
                await task.value
            } onCancel: {
                task.cancel()
            }
            if tasks[session.id]?.id == id { tasks.removeValue(forKey: session.id) }
        }
    }

    private static func load(session: Session, context: ModelContext) async {
        let connectionKey = session.connectionKey
        if session.followsRemote, !session.isStreaming, !Task.isCancelled, let endpoint = session.endpoint,
            let (data, response) = await HTTPClient.get(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/history", timeout: 15,
                headers: session.remoteHistoryETag.map { ["If-None-Match": $0] } ?? [:]),
            response.statusCode == 200,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let history = object["thread"] as? [String: Any],
            session.connectionKey == connectionKey,
            session.followsRemote, !session.isStreaming, !Task.isCancelled
        {
            if await ChatActions.importHistory(
                history, session: session, context: context, requiringRemoteFollow: true),
                session.connectionKey == connectionKey
            {
                SessionActions.setRemoteHistoryETag(response.value(forHTTPHeaderField: "ETag"), for: session)
                if let data = try? JSONSerialization.data(withJSONObject: history.filter { $0.key != "turns" }),
                    let thread = try? JSONDecoder().decode(SessionRemoteThread.self, from: data)
                {
                    SessionActions.refreshRemoteTitle(thread, for: session)
                }
            }
        }
    }
}
