import Foundation
import SwiftData

@MainActor
enum SessionForkService {
    private static var operations:
        [UUID: (generation: UUID, task: Task<(Bool, String?, UUID?), Never>, waiters: Set<UUID>)] = [:]

    static func fork(
        session: Session, context: ModelContext, store: SessionForkStore, startAnother: Bool = false
    ) async -> Bool {
        store.isForking = true
        store.error = nil
        defer { store.isForking = false }
        if !Task.isCancelled, !session.isDeleted, let endpoint = session.endpoint, !endpoint.isDeleted,
            session.path != nil,
            !(session.isStreaming || session.remoteIsRunning)
                || endpoint.capabilities?.contains("codexActiveFork") == true
        {
            let scope = session.forkScopeKey
            let connection = session.connectionKey
            if startAnother, let previous = store.unconfirmedRequestId,
                session.pendingForkScope == scope, session.pendingForkId == previous,
                operations[previous] == nil
            {
                SessionActions.finishFork(session, id: previous)
            }
            store.unconfirmedRequestId = nil
            let id = SessionActions.prepareFork(session, scope: scope)
            if (try? context.save()) != nil {
                if operations[id] == nil {
                    operations[id] = (
                        UUID(),
                        Task {
                            let result = SessionForkStore()
                            return (
                                await complete(
                                    session: session, id: id, scope: scope, connection: connection,
                                    context: context, store: result),
                                result.error, result.unconfirmedRequestId
                            )
                        }, []
                    )
                }
                if let operation = operations[id] {
                    let waiter = UUID()
                    operations[id]?.waiters.insert(waiter)
                    let result = await withTaskCancellationHandler {
                        await operation.task.value
                    } onCancel: {
                        Task { @MainActor in
                            if operations[id]?.generation == operation.generation {
                                operations[id]?.waiters.remove(waiter)
                                if operations[id]?.waiters.isEmpty == true { operation.task.cancel() }
                            }
                        }
                    }
                    if operations[id]?.generation == operation.generation { operations[id] = nil }
                    store.error = result.1
                    store.unconfirmedRequestId = result.2
                    return result.0 && !Task.isCancelled
                }
            } else {
                store.error = "Could not save this side-chat request. Check the available storage on your iPhone."
            }
        }
        if store.error == nil { store.error = "Check the connection and make sure the last turn has finished." }
        return false
    }

    private static func complete(
        session: Session, id: UUID, scope: String, connection: String, context: ModelContext,
        store: SessionForkStore
    ) async -> Bool {
        if !Task.isCancelled, !session.isDeleted, let endpoint = session.endpoint, !endpoint.isDeleted,
            let path = session.path, session.forkScopeKey == scope, session.connectionKey == connection,
            session.pendingForkId == id,
            let (data, response) = await HTTPClient.post(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/fork",
                body: ["newSessionId": id.uuidString, "path": path], timeout: 30),
            !Task.isCancelled, session.forkScopeKey == scope, session.connectionKey == connection,
            session.pendingForkId == id,
            !session.isDeleted, !endpoint.isDeleted
        {
            if response.statusCode != 200,
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let error = object["error"] as? String, !error.isEmpty
            {
                store.error = String(error.prefix(500))
                if object["code"] as? String == "fork_outcome_unknown", object["retriable"] as? Bool == false {
                    store.unconfirmedRequestId = id
                    store.error =
                        "The host could not confirm whether this side chat was created. Check Remote chats first. Starting another may create a second side chat."
                }
            }
            if response.statusCode == 200,
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let returnedId = object["sessionId"] as? String, UUID(uuidString: returnedId) == id,
                let threadId = object["threadId"] as? String, !threadId.isEmpty,
                threadId != session.codexThreadId,
                let history = object["thread"] as? [String: Any], history["id"] as? String == threadId,
                let cwd = history["cwd"] as? String, cwd.hasPrefix("/"), !cwd.hasPrefix("//"),
                !cwd.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                let turns = history["turns"] as? [[String: Any]],
                (history["status"] as? [String: Any])?["type"] as? String != "active",
                !turns.contains(where: { $0["status"] as? String == "inProgress" })
            {
                let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
                if (try? context.fetch(descriptor).first) == nil {
                    let transaction = ModelContext(context.container)
                    transaction.autosaveEnabled = false
                    let sourceId = session.id
                    if let source = try? transaction.fetch(
                        FetchDescriptor<Session>(predicate: #Predicate { $0.id == sourceId })
                    ).first {
                        let fork = SessionActions.fork(
                            source, id: id, path: (cwd as NSString).standardizingPath, context: transaction,
                            copyHistory: false)
                        SessionActions.setCodexThreadId(threadId, for: fork)
                        let imported = await ChatActions.importHistory(history, session: fork, context: transaction)
                        if imported, !Task.isCancelled, session.forkScopeKey == scope,
                            session.connectionKey == connection, session.pendingForkId == id,
                            session.codexThreadId == source.codexThreadId, !session.isDeleted, !endpoint.isDeleted
                        {
                            if (try? transaction.save()) == nil {
                                store.error =
                                    "The side chat was created on the host, but could not be saved here. Try again to recover it."
                            }
                        }
                    }
                }
                if !Task.isCancelled, session.forkScopeKey == scope,
                    session.connectionKey == connection, session.pendingForkId == id,
                    !session.isDeleted, !endpoint.isDeleted,
                    let fork = try? context.fetch(descriptor).first,
                    fork.parentSessionId == session.id, fork.codexThreadId == threadId,
                    fork.endpoint?.cacheId == endpoint.cacheId
                {
                    SessionActions.finishFork(session, id: id)
                    if (try? context.save()) != nil {
                        WindowActions.open(
                            fork, among: (try? context.fetch(FetchDescriptor<Window>())) ?? [], context: context)
                        return true
                    }
                    SessionActions.restoreFork(session, id: id, scope: scope)
                    store.error = "The side chat is saved. Reopen it from your chats or try again."
                }
            }
        }
        if store.error == nil {
            store.error = "Could not confirm this side chat. Try again to recover the same request."
        }
        return false
    }
}
