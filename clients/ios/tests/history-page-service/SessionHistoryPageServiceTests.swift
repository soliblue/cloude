import Foundation
import SwiftData

@main struct SessionHistoryPageServiceTests {
    static func turn(_ id: String, status: String = "completed", text: String? = nil) -> [String: Any] {
        [
            "id": id, "status": status, "itemsView": "full", "startedAt": 1000,
            "items": [["id": "item-" + id, "type": "agentMessage", "text": text ?? id]],
        ]
    }

    static func page(_ turns: [[String: Any]], next: String? = nil, backwards: String? = nil) -> [String: Any] {
        var result: [String: Any] = ["threadId": "native", "data": turns]
        if let next { result["nextCursor"] = next }
        if let backwards { result["backwardsCursor"] = backwards }
        return result
    }

    static func metadata(_ turns: [[String: Any]]? = nil, active: Bool = false) -> [String: Any] {
        var result: [String: Any] = [
            "id": "native", "cwd": "/fixture", "preview": "Remote title", "updatedAt": 1000,
            "status": ["type": active ? "active" : "idle"],
        ]
        if let turns { result["turns"] = turns }
        return result
    }

    @MainActor static func reset(_ responses: [[String: Any]?], beforeGet: ((Int) async -> Void)? = nil) {
        HTTPClient.calls = []
        HTTPClient.responses = responses
        HTTPClient.beforeGet = beforeGet
    }

    @MainActor static func makeSession(_ context: ModelContext, endpoint: Endpoint) -> Session {
        let session = Session(endpoint: endpoint, path: "/fixture")
        session.provider = .codex
        session.codexThreadId = "native"
        session.existsOnServer = true
        session.followsRemote = true
        context.insert(session)
        return session
    }

    @MainActor static func main() async throws {
        let container = try ModelContainer(
            for: Session.self, Endpoint.self, ChatMessage.self, ChatToolCall.self, ChatGitChange.self,
            ChatHistoryTurnRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let endpoint = Endpoint()
        context.insert(endpoint)
        try context.save()
        let privateContext = ModelContext(container)
        privateContext.autosaveEnabled = false
        let owner = try privateContext.fetch(FetchDescriptor<Endpoint>()).first!
        let initial = makeSession(privateContext, endpoint: owner)
        let id = initial.id
        reset([page([turn("latest"), turn("prior")], next: "older-1", backwards: "latest-anchor")]) { _ in
            endpoint.name = "Renamed while importing"
            precondition(try! context.fetchCount(FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })) == 0)
        }
        let prepared = await SessionHistoryPageService.prepareInitial(
            session: initial, metadata: metadata(), context: privateContext, transportEndpoint: endpoint,
            isCurrent: { true })
        precondition(prepared && initial.remoteHistoryOlderCursor == "older-1")
        precondition(try! context.fetchCount(FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })) == 0)
        try privateContext.save()
        precondition(owner.capabilities == ["codexHistoryPages"] && owner.name == "Original host")
        precondition(
            endpoint.name == "Renamed while importing"
                && endpoint.capabilities?.contains("testResponseCapability") == true)
        try context.save()
        let freshOwner = try ModelContext(container).fetch(FetchDescriptor<Endpoint>()).first!
        precondition(
            freshOwner.name == "Renamed while importing"
                && freshOwner.capabilities?.contains("testResponseCapability") == true)
        let session = try context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })).first!
        precondition(session.remoteHistoryPagingInitialized && session.title == "Remote title")
        let stable = try context.fetch(FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == id }))
        let stableIDs = Dictionary(uniqueKeysWithValues: stable.map { ($0.remoteItemId!, $0.id) })
        session.remoteIsRunning = true
        session.remoteTurnStatus = "inProgress"
        session.hasCustomTitle = true
        session.title = "My title"
        try context.save()
        reset([page([turn("oldest")])]) { _ in session.isPinned = true }
        let earlier = await SessionHistoryPageService.loadEarlier(session: session, context: context)
        precondition(earlier && session.remoteHistoryOlderCursor == nil)
        precondition(session.remoteHistoryNewerCursor == "latest-anchor" && session.remoteIsRunning)
        precondition(session.remoteTurnStatus == "inProgress" && session.title == "My title" && session.isPinned)
        precondition(HTTPClient.calls[0].1 == ["limit": "25", "sortDirection": "desc", "cursor": "older-1"])
        let ordered = try context.fetch(
            FetchDescriptor<ChatHistoryTurnRecord>(
                predicate: #Predicate { $0.sessionId == id }, sortBy: [SortDescriptor(\.order)]))
        precondition(ordered.map(\.turnId) == ["oldest", "prior", "latest"])
        for message in stable { precondition(message.id == stableIDs[message.remoteItemId!]) }
        reset([
            ["thread": metadata(active: true)],
            page([turn("latest"), turn("newer", status: "inProgress")], next: "catch-up"),
            page([]),
        ])
        await SessionHistoryPageService.refresh(session: session, context: context)
        precondition(session.remoteHistoryNewerCursor == "catch-up")
        precondition(session.remoteTurnStatus == "inProgress" && session.remoteIsRunning)
        precondition(
            HTTPClient.calls.map { $0.1["includeTurns"] ?? $0.1["cursor"] ?? "" } == [
                "false", "latest-anchor", "catch-up",
            ])
        reset([["thread": metadata()], page([turn("after-retry")], next: "resume-here"), nil])
        await SessionHistoryPageService.refresh(session: session, context: context)
        precondition(session.remoteHistoryNewerCursor == "resume-here")
        precondition(SessionHistoryPageStore.shared.errors[id] != nil)
        reset([["thread": metadata()], page([turn("after-retry"), turn("finished")])])
        await SessionHistoryPageService.refresh(session: session, context: context)
        precondition(HTTPClient.calls[1].1["cursor"] == "resume-here")
        precondition(session.remoteTurnStatus == "completed" && !session.remoteIsRunning)
        precondition(SessionHistoryPageStore.shared.errors[id] == nil)
        let count = try context.fetchCount(
            FetchDescriptor<ChatHistoryTurnRecord>(predicate: #Predicate { $0.sessionId == id }))
        reset([["thread": metadata()], page([turn("stale")])]) { index in
            if index == 1 { session.lastSeq += 1 }
        }
        await SessionHistoryPageService.refresh(session: session, context: context)
        precondition(
            try! context.fetchCount(
                FetchDescriptor<ChatHistoryTurnRecord>(predicate: #Predicate { $0.sessionId == id })) == count)
        precondition(session.remoteHistoryNewerCursor == "resume-here")
        try context.save()
        reset([["thread": metadata()], page([turn("credential-stale")])]) { index in
            if index == 1 { endpoint.connectionRevision = UUID() }
        }
        await SessionHistoryPageService.refresh(session: session, context: context)
        precondition(
            try! context.fetchCount(
                FetchDescriptor<ChatHistoryTurnRecord>(predicate: #Predicate { $0.sessionId == id })) == count)
        reset([["thread": metadata()], page([turn("after-rotation")])])
        await SessionHistoryPageService.refresh(session: session, context: context)
        precondition(
            try! context.fetchCount(
                FetchDescriptor<ChatHistoryTurnRecord>(predicate: #Predicate { $0.sessionId == id })) == count + 1)
        let oldHost = endpoint.host
        endpoint.host = "different.invalid"
        reset([])
        await SessionHistoryPageService.refresh(session: session, context: context)
        precondition(HTTPClient.calls.isEmpty && SessionHistoryPageStore.shared.errors[id] != nil)
        endpoint.host = oldHost
        let legacy = makeSession(context, endpoint: endpoint)
        try context.save()
        reset([["thread": metadata([turn("legacy-first"), turn("legacy-last")])], nil])
        await SessionHistoryPageService.refresh(session: legacy, context: context)
        precondition(!legacy.remoteHistoryPagingInitialized)
        reset([
            ["thread": metadata([turn("legacy-first"), turn("legacy-last"), turn("legacy-added")])],
            page([turn("legacy-added"), turn("legacy-last")], next: "ignored-cached", backwards: "legacy-anchor"),
        ])
        await SessionHistoryPageService.refresh(session: legacy, context: context)
        precondition(legacy.remoteHistoryPagingInitialized && legacy.remoteHistoryOlderCursor == nil)
        reset([["thread": metadata()], page([])])
        await SessionHistoryPageService.refresh(session: legacy, context: context)
        precondition(HTTPClient.calls[0].1["includeTurns"] == "false")
        let malformed = makeSession(context, endpoint: endpoint)
        try context.save()
        reset([["thread": metadata()]])
        await SessionHistoryPageService.refresh(session: malformed, context: context)
        precondition(!malformed.remoteHistoryPagingInitialized && HTTPClient.calls.count == 1)
        let empty = makeSession(context, endpoint: endpoint)
        reset([page([])])
        let emptyPrepared = await SessionHistoryPageService.prepareInitial(
            session: empty, metadata: metadata(), context: context, isCurrent: { true })
        precondition(emptyPrepared)
        try context.save()
        reset([["thread": metadata()], page([turn("first-later")], backwards: "new-anchor")])
        await SessionHistoryPageService.refresh(session: empty, context: context)
        precondition(empty.remoteHistoryNewerCursor == "new-anchor" && HTTPClient.calls[1].1["sortDirection"] == "desc")
        let cancelCount = try context.fetchCount(FetchDescriptor<ChatHistoryTurnRecord>())
        var task: Task<Void, Never>?
        reset([["thread": metadata()], page([turn("cancelled")])]) { index in
            if index == 1 { task?.cancel() }
        }
        task = Task { @MainActor in await SessionHistoryPageService.refresh(session: empty, context: context) }
        await task!.value
        task = nil
        precondition(try! context.fetchCount(FetchDescriptor<ChatHistoryTurnRecord>()) == cancelCount)
        precondition(!SessionHistoryPageStore.shared.loading.contains(empty.id))
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storage) }
        let schema = Schema([
            Session.self, Endpoint.self, ChatMessage.self, ChatToolCall.self, ChatGitChange.self,
            ChatHistoryTurnRecord.self,
        ])
        let url = storage.appendingPathComponent("history.store")
        do {
            let writable = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
            let seed = ModelContext(writable)
            seed.autosaveEnabled = false
            let endpoint = Endpoint()
            seed.insert(endpoint)
            let saved = makeSession(seed, endpoint: endpoint)
            reset([page([turn("saved")], next: "older-saved", backwards: "newer-saved")])
            let prepared = await SessionHistoryPageService.prepareInitial(
                session: saved, metadata: metadata(), context: seed, isCurrent: { true })
            precondition(prepared)
            try seed.save()
        }
        let readOnlyContainer = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: url, allowsSave: false))
        let readOnly = ModelContext(readOnlyContainer)
        readOnly.autosaveEnabled = false
        let saved = try readOnly.fetch(FetchDescriptor<Session>()).first!
        reset([page([turn("unsaved-older")])])
        let failedSave = await SessionHistoryPageService.loadEarlier(session: saved, context: readOnly)
        precondition(!failedSave && saved.remoteHistoryOlderCursor == "older-saved")
        precondition(saved.remoteHistoryNewerCursor == "newer-saved")
        precondition(try! readOnly.fetchCount(FetchDescriptor<ChatMessage>()) == 1)
        precondition(try! readOnly.fetchCount(FetchDescriptor<ChatHistoryTurnRecord>()) == 1)
        precondition(!SessionHistoryPageStore.shared.loading.contains(saved.id))
        precondition(SessionHistoryPageStore.shared.errors[saved.id] != nil)
        print(
            "PASS page service atomic initial publication, earlier cursors, ordered catch-up, partial failure retry, live sequence/credential fences, custom titles, legacy migration retry, empty history and cancellation"
        )
    }
}
