import Foundation
import SwiftData

@MainActor enum SessionHistoryPageService {
    static func prepareInitial(
        session: Session, metadata: [String: Any], context: ModelContext,
        transportEndpoint: Endpoint? = nil, isCurrent: () -> Bool
    ) async -> Bool {
        if let endpoint = transportEndpoint ?? session.endpoint, let threadId = session.codexThreadId,
            metadata["id"] as? String == threadId, isCurrent(),
            let page = await page(endpoint: endpoint, sessionId: session.id, cursor: nil, newer: false),
            page.threadId == threadId, isCurrent(),
            await ChatActions.importPage(page, direction: .initial, session: session, context: context),
            isCurrent(), !Task.isCancelled
        {
            applyMetadata(metadata, to: session)
            SessionActions.setRemoteTurnStatus(page.turns.first?.status, for: session)
            SessionActions.setHistoryPaging(older: page.nextCursor, newer: page.backwardsCursor, for: session)
            return true
        }
        return false
    }

    static func loadEarlier(session: Session, context: ModelContext) async -> Bool {
        await load(session: session, context: context, older: true)
    }

    static func refresh(session: Session, context: ModelContext) async {
        _ = await load(session: session, context: context, older: false)
    }

    private static func page(
        endpoint: Endpoint, sessionId: UUID, cursor: String?, newer: Bool
    ) async -> ChatHistoryPage? {
        var query = ["limit": "25", "sortDirection": newer ? "asc" : "desc"]
        if let cursor { query["cursor"] = cursor }
        if let (data, response) = await HTTPClient.get(
            endpoint: endpoint, path: "/sessions/\(sessionId.uuidString)/turns", query: query, timeout: 20),
            response.statusCode == 200, !Task.isCancelled
        {
            return await ChatHistoryPage.decode(data)
        }
        return nil
    }

    private static func load(session: Session, context: ModelContext, older: Bool) async -> Bool {
        let store = SessionHistoryPageStore.shared
        if !Task.isCancelled, !store.loading.contains(session.id), !session.isStreaming,
            session.provider == .codex, session.existsOnServer, session.modelContext === context,
            !session.isDeleted, !session.isArchived, older || session.followsRemote,
            let endpoint = session.endpoint, endpoint.capabilities?.contains("codexHistoryPages") == true,
            let threadId = session.codexThreadId
        {
            let id = session.id
            let connection = session.connectionKey
            let scope = session.historyScopeKey
            let sequence = session.lastSeq
            store.loading.insert(id)
            store.errors.removeValue(forKey: id)
            defer { store.loading.remove(id) }
            let isCurrent = {
                !Task.isCancelled && session.modelContext === context && !session.isDeleted && !session.isArchived
                    && !session.isStreaming && session.provider == .codex && session.existsOnServer
                    && (older || session.followsRemote) && session.connectionKey == connection
                    && session.historyScopeKey == scope && session.codexThreadId == threadId
                    && session.lastSeq == sequence
            }
            let beforeApply = { isCurrent() && (try? context.save()) != nil }
            if session.remoteHistoryPagingInitialized && session.remoteHistoryPagingScope != scope {
                store.errors[id] = "This history belongs to a different task connection. Open the remote task again."
                return false
            }
            if older && (!session.remoteHistoryPagingInitialized || session.remoteHistoryOlderCursor == nil) {
                return false
            }
            var metadata: [String: Any]?
            if !older {
                if let (data, response) = await HTTPClient.get(
                    endpoint: endpoint, path: "/sessions/\(id.uuidString)/history",
                    query: ["includeTurns": session.remoteHistoryPagingInitialized ? "false" : "true"], timeout: 30),
                    response.statusCode == 200, isCurrent(),
                    let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let history = object["thread"] as? [String: Any], history["id"] as? String == threadId
                {
                    metadata = history
                    if !session.remoteHistoryPagingInitialized {
                        if !(await ChatActions.importHistory(
                            history, session: session, context: context, recordTimeline: true,
                            beforeApply: beforeApply, afterApply: { save(context) })) || !isCurrent()
                        {
                            if isCurrent() {
                                store.errors[id] = "Could not prepare saved history. Reconnect and refresh this task."
                            }
                            return false
                        }
                    }
                } else {
                    if isCurrent() {
                        store.errors[id] = "Could not refresh this task. Saved messages remain available offline."
                    }
                    return false
                }
            }
            if !session.remoteHistoryPagingInitialized {
                if let metadata, let initial = await page(endpoint: endpoint, sessionId: id, cursor: nil, newer: false),
                    initial.threadId == threadId, isCurrent(),
                    !initial.turns.isEmpty || ((metadata["turns"] as? [Any]) ?? []).isEmpty,
                    await ChatActions.importPage(
                        initial, direction: .initial, session: session, context: context,
                        beforeApply: beforeApply,
                        afterApply: {
                            applyMetadata(metadata, to: session)
                            SessionActions.setRemoteTurnStatus(initial.turns.first?.status, for: session)
                            SessionActions.setHistoryPaging(
                                older: ((metadata["turns"] as? [Any]) ?? []).isEmpty ? initial.nextCursor : nil,
                                newer: initial.backwardsCursor, for: session)
                            return save(context)
                        })
                {
                    return true
                }
                if isCurrent() {
                    store.errors[id] = "Could not save paged history. Your existing messages have been kept."
                }
                return false
            }
            var cursor = older ? session.remoteHistoryOlderCursor : session.remoteHistoryNewerCursor
            var visited: Set<String> = []
            repeat {
                let descending = older || cursor == nil
                if let cursor, !visited.insert(cursor).inserted {
                    store.errors[id] = "The host repeated a history page. Update the daemon and retry."
                    return false
                }
                if let next = await page(endpoint: endpoint, sessionId: id, cursor: cursor, newer: !descending),
                    next.threadId == threadId, isCurrent(),
                    await ChatActions.importPage(
                        next, direction: older ? .older : descending ? .initial : .newer,
                        session: session, context: context, beforeApply: beforeApply,
                        afterApply: {
                            if let metadata { applyMetadata(metadata, to: session) }
                            if !older && !next.turns.isEmpty && (descending || next.nextCursor == nil) {
                                SessionActions.setRemoteTurnStatus(
                                    descending ? next.turns.first?.status : next.turns.last?.status, for: session)
                            }
                            SessionActions.setHistoryPaging(
                                older: older || descending ? next.nextCursor : session.remoteHistoryOlderCursor,
                                newer: older
                                    ? session.remoteHistoryNewerCursor
                                    : descending ? next.backwardsCursor : next.nextCursor ?? cursor,
                                for: session)
                            return save(context)
                        })
                {
                    if older || descending || next.nextCursor == nil { return true }
                    cursor = next.nextCursor
                    await Task.yield()
                } else {
                    if isCurrent() {
                        store.errors[id] = "Could not load this history page. Saved messages remain available offline."
                    }
                    return false
                }
            } while isCurrent()
        }
        return false
    }

    private static func save(_ context: ModelContext) -> Bool {
        if (try? context.save()) != nil {
            return true
        }
        context.rollback()
        return false
    }

    private static func applyMetadata(_ history: [String: Any], to session: Session) {
        if let status = (history["status"] as? [String: Any])?["type"] as? String {
            SessionActions.setRemoteRunning(status == "active", for: session)
        }
        if let data = try? JSONSerialization.data(withJSONObject: history.filter { $0.key != "turns" }),
            let thread = try? JSONDecoder().decode(SessionRemoteThread.self, from: data)
        {
            SessionActions.refreshRemoteTitle(thread, for: session)
        }
    }
}
