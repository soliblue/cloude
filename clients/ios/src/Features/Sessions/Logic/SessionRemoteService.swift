import Foundation
import SwiftData

enum SessionRemoteService {
    static func open(
        threadId: String, endpoint: Endpoint, store: SessionRemoteStore, context: ModelContext
    ) async -> Bool {
        let scope = endpoint.cacheId
        guard !Task.isCancelled else { return false }
        store.openingId = threadId
        store.openingScope = scope
        store.error = nil
        guard endpointIsCurrent(endpoint: endpoint, scope: scope, context: context) else {
            store.openingId = nil
            store.openingScope = nil
            return false
        }
        let endpointId = endpoint.id
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.codexThreadId == threadId && $0.endpoint?.id == endpointId })
        if let existing = try? context.fetch(descriptor).first {
            activate(existing, thread: nil, endpoint: endpoint, scope: scope, store: store, context: context)
            return true
        }
        if let (data, response) = await HTTPClient.get(
            endpoint: endpoint, path: "/codex/threads/\(threadId)", timeout: 30),
            isCurrent(endpoint: endpoint, scope: scope, store: store, context: context, threadId: threadId),
            response.statusCode == 200,
            let detail = try? JSONDecoder().decode(SessionRemoteThreadDetail.self, from: data)
        {
            return await open(
                detail.thread, endpoint: endpoint, store: store, context: context, restoreArchived: false, scope: scope)
        }
        failOpening(
            threadId: threadId, endpoint: endpoint, scope: scope, store: store,
            message: "Could not open this agent task. Check your connection and try again.")
        return false
    }

    static func load(
        endpoint: Endpoint, store: SessionRemoteStore, search: String, archived: Bool, more: Bool = false,
        section: SessionSectionFilter = .all
    ) async {
        let scope = endpoint.cacheId
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestKey = "\(scope)|\(term)|\(archived)|\(section)"
        if store.requestKey != requestKey {
            store.threads = []
            store.nextCursor = nil
            store.requestKey = requestKey
        }
        let generation = UUID()
        store.generation = generation
        store.isLoading = true
        store.error = nil
        var query = ["archived": String(archived)]
        if !term.isEmpty { query["search"] = term }
        query.merge(section.query) { _, new in new }
        if more, let cursor = store.nextCursor { query["cursor"] = cursor }
        let response = await HTTPClient.get(endpoint: endpoint, path: "/codex/threads", query: query, timeout: 15)
        if store.generation == generation && endpoint.cacheId == scope {
            if let (data, response) = response, !Task.isCancelled, response.statusCode == 200,
                let page = try? JSONDecoder().decode(SessionRemoteThreadPage.self, from: data)
            {
                store.threads =
                    more
                    ? store.threads + page.data.filter { next in !store.threads.contains(where: { $0.id == next.id }) }
                    : page.data
                store.nextCursor = page.nextCursor
            } else if !Task.isCancelled {
                store.error = "Could not load remote chats. Check the connection and Codex sign-in on this machine."
            }
            store.isLoading = false
        }
    }

    static func open(
        _ thread: SessionRemoteThread, endpoint: Endpoint, store: SessionRemoteStore, context: ModelContext,
        restoreArchived: Bool = false
    ) async -> Bool {
        await open(
            thread, endpoint: endpoint, store: store, context: context, restoreArchived: restoreArchived,
            scope: endpoint.cacheId)
    }

    private static func open(
        _ thread: SessionRemoteThread, endpoint: Endpoint, store: SessionRemoteStore, context: ModelContext,
        restoreArchived: Bool, scope: UUID
    ) async -> Bool {
        store.openingId = thread.id
        store.openingScope = scope
        store.error = nil
        guard isCurrent(endpoint: endpoint, scope: scope, store: store, context: context, threadId: thread.id) else {
            return false
        }
        if restoreArchived {
            if let (_, response) = await HTTPClient.post(
                endpoint: endpoint, path: "/sessions/\(thread.id)/archive", body: ["archived": false]),
                isCurrent(endpoint: endpoint, scope: scope, store: store, context: context, threadId: thread.id),
                response.statusCode == 200
            {
            } else {
                failOpening(
                    threadId: thread.id, endpoint: endpoint, scope: scope, store: store,
                    message: "Could not restore this remote chat. Check your connection and try again.")
                return false
            }
        }
        guard isCurrent(endpoint: endpoint, scope: scope, store: store, context: context, threadId: thread.id) else {
            return false
        }
        let threadId = thread.id
        let endpointId = endpoint.id
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.codexThreadId == threadId && $0.endpoint?.id == endpointId })
        if let existing = try? context.fetch(descriptor).first {
            SessionActions.setArchived(existing, false)
            SessionActions.refreshRemoteTitle(thread, for: existing)
            let windows = (try? context.fetch(FetchDescriptor<Window>())) ?? []
            if let window = windows.first(where: { $0.session?.id == existing.id }) {
                WindowActions.activate(window, among: windows)
            } else {
                WindowActions.open(existing, among: windows, context: context)
            }
            finishOpening(threadId: thread.id, endpoint: endpoint, scope: scope, store: store)
            return true
        }
        let sessionId = UUID()
        if let (data, response) = await HTTPClient.post(
            endpoint: endpoint, path: "/sessions/\(sessionId.uuidString)/import", body: ["threadId": thread.id],
            timeout: 30),
            isCurrent(endpoint: endpoint, scope: scope, store: store, context: context, threadId: thread.id),
            response.statusCode == 200,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let history = object["thread"] as? [String: Any]
        {
            guard isCurrent(endpoint: endpoint, scope: scope, store: store, context: context, threadId: thread.id)
            else {
                return false
            }
            let session = SessionActions.importThread(thread, id: sessionId, endpoint: endpoint, context: context)
            let imported = await ChatActions.importHistory(history, session: session, context: context)
            guard imported,
                isCurrent(endpoint: endpoint, scope: scope, store: store, context: context, threadId: thread.id)
            else {
                ChatActions.discardHistory(sessionId: session.id, context: context)
                context.delete(session)
                return false
            }
            WindowActions.open(session, among: (try? context.fetch(FetchDescriptor<Window>())) ?? [], context: context)
            finishOpening(threadId: thread.id, endpoint: endpoint, scope: scope, store: store)
            return true
        }
        failOpening(
            threadId: thread.id, endpoint: endpoint, scope: scope, store: store,
            message: "Could not open this chat. Try again after reconnecting.")
        return false
    }

    private static func isCurrent(
        endpoint: Endpoint, scope: UUID, store: SessionRemoteStore, context: ModelContext, threadId: String
    ) -> Bool {
        guard store.openingId == threadId, store.openingScope == scope,
            endpointIsCurrent(endpoint: endpoint, scope: scope, context: context)
        else { return false }
        return true
    }

    private static func endpointIsCurrent(endpoint: Endpoint, scope: UUID, context: ModelContext) -> Bool {
        guard !Task.isCancelled, endpoint.cacheId == scope else { return false }
        let endpointId = endpoint.id
        return
            (try? context.fetch(
                FetchDescriptor<Endpoint>(predicate: #Predicate { $0.id == endpointId })
            ).first?.cacheId == scope) == true
    }

    private static func finishOpening(
        threadId: String, endpoint: Endpoint, scope: UUID, store: SessionRemoteStore
    ) {
        if endpoint.cacheId == scope, store.openingId == threadId, store.openingScope == scope {
            store.openingId = nil
            store.openingScope = nil
        }
    }

    private static func failOpening(
        threadId: String, endpoint: Endpoint, scope: UUID, store: SessionRemoteStore, message: String
    ) {
        if endpoint.cacheId == scope, store.openingId == threadId, store.openingScope == scope {
            store.error = message
            store.openingId = nil
            store.openingScope = nil
        }
    }

    private static func activate(
        _ session: Session, thread: SessionRemoteThread?, endpoint: Endpoint, scope: UUID,
        store: SessionRemoteStore, context: ModelContext
    ) {
        SessionActions.setArchived(session, false)
        if let thread { SessionActions.refreshRemoteTitle(thread, for: session) }
        let windows = (try? context.fetch(FetchDescriptor<Window>())) ?? []
        if let window = windows.first(where: { $0.session?.id == session.id }) {
            WindowActions.activate(window, among: windows)
        } else {
            WindowActions.open(session, among: windows, context: context)
        }
        finishOpening(
            threadId: session.codexThreadId ?? "", endpoint: endpoint, scope: scope, store: store)
    }

    static func archive(
        _ thread: SessionRemoteThread, archived: Bool, endpoint: Endpoint, store: SessionRemoteStore,
        context: ModelContext
    ) async {
        let scope = endpoint.cacheId
        guard endpointIsCurrent(endpoint: endpoint, scope: scope, context: context) else { return }
        if let (_, response) = await HTTPClient.post(
            endpoint: endpoint, path: "/sessions/\(thread.id)/archive", body: ["archived": archived]),
            endpointIsCurrent(endpoint: endpoint, scope: scope, context: context),
            response.statusCode == 200
        {
            store.threads.removeAll { $0.id == thread.id }
            let threadId = thread.id
            let endpointId = endpoint.id
            let descriptor = FetchDescriptor<Session>(
                predicate: #Predicate<Session> { $0.codexThreadId == threadId && $0.endpoint?.id == endpointId })
            for session in (try? context.fetch(descriptor)) ?? [] { SessionActions.setArchived(session, archived) }
        } else if endpointIsCurrent(endpoint: endpoint, scope: scope, context: context) {
            store.error = "Could not update this chat. Try again after reconnecting."
        }
    }
}
