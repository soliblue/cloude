import Foundation
import SwiftData

@main struct ChatHistoryPageTests {
    static func turn(_ id: String, _ items: [[String: Any]], status: String = "completed") -> [String: Any] {
        ["id": id, "status": status, "itemsView": "full", "startedAt": 1000, "items": items]
    }

    static func text(_ id: String, _ value: String = "text") -> [String: Any] {
        ["id": id, "type": "agentMessage", "text": value]
    }

    static func page(_ turns: [[String: Any]]) async -> ChatHistoryPage {
        let decoded = await ChatHistoryPage.decode(
            try! JSONSerialization.data(withJSONObject: ["threadId": "native", "data": turns]))
        return decoded!
    }

    @MainActor static func main() async throws {
        let container = try ModelContainer(
            for: Session.self, Endpoint.self, ChatMessage.self, ChatToolCall.self, ChatGitChange.self,
            ChatHistoryTurnRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let endpoint = Endpoint()
        let session = Session(endpoint: endpoint)
        context.insert(endpoint)
        context.insert(session)
        try context.save()
        let initial = await page([
            turn("a-latest", [text("last")]),
            turn(
                "z-previous",
                [["id": "user", "type": "userMessage", "content": [["type": "localImage", "path": "/tmp/image.png"]]]]),
        ])
        let initialOK = await ChatActions.importPage(initial, direction: .initial, session: session, context: context)
        precondition(initialOK)
        var messages = try! context.fetch(FetchDescriptor<ChatMessage>())
        let stable = Dictionary(uniqueKeysWithValues: messages.map { ($0.remoteItemId!, $0.id) })
        precondition(messages.first { $0.remoteItemId == "user" }!.timelineOrder == -1)
        precondition(messages.first { $0.remoteItemId == "last" }!.timelineOrder == 0)
        let user = messages.first { $0.remoteItemId == "user" }!
        user.imagesData = [Data([1, 2, 3])]
        let repeated = await ChatActions.importPage(initial, direction: .initial, session: session, context: context)
        precondition(repeated && user.imagesData == [Data([1, 2, 3])])
        precondition(
            Dictionary(
                uniqueKeysWithValues: (try! context.fetch(FetchDescriptor<ChatMessage>())).map {
                    ($0.remoteItemId!, $0.id)
                }) == stable)
        let older = await page([turn("empty-middle", []), turn("older-start", [text("old")])])
        let olderOK = await ChatActions.importPage(older, direction: .older, session: session, context: context)
        precondition(olderOK)
        var records = try! context.fetch(FetchDescriptor<ChatHistoryTurnRecord>(sortBy: [SortDescriptor(\.order)]))
        precondition(records.map(\.turnId) == ["older-start", "empty-middle", "z-previous", "a-latest"])
        precondition(records.map(\.order) == [-3, -2, -1, 0])
        let newer = await page([
            turn("a-latest", [text("last", "updated")]), turn("new-empty", []),
            turn("not-lexically-new", [text("new")]),
        ])
        let newerOK = await ChatActions.importPage(newer, direction: .newer, session: session, context: context)
        precondition(newerOK)
        records = try! context.fetch(FetchDescriptor<ChatHistoryTurnRecord>(sortBy: [SortDescriptor(\.order)]))
        precondition(records.map(\.order) == [-3, -2, -1, 0, 1, 2])
        precondition(messages.first { $0.remoteItemId == "last" }!.text == "updated")
        let withTool = await page([
            turn(
                "not-lexically-new",
                [text("new"), ["id": "tool", "type": "commandExecution", "command": "pwd", "status": "inProgress"]],
                status: "inProgress")
        ])
        let withToolOK = await ChatActions.importPage(withTool, direction: .newer, session: session, context: context)
        precondition(withToolOK)
        let call = try! context.fetch(FetchDescriptor<ChatToolCall>()).first!
        let toolMessageId = call.messageId
        precondition(call.order == 1 && call.state == .pending)
        let final = await page([
            turn(
                "not-lexically-new",
                [
                    text("inserted"), text("new", "final"),
                    [
                        "id": "tool", "type": "commandExecution", "command": "pwd", "status": "completed",
                        "aggregatedOutput": "done", "exitCode": 0,
                    ],
                ])
        ])
        let finalOK = await ChatActions.importPage(final, direction: .newer, session: session, context: context)
        precondition(finalOK)
        precondition(
            call.messageId == toolMessageId && call.order == 2 && call.result == "done" && call.state == .succeeded)
        messages = try! context.fetch(FetchDescriptor<ChatMessage>())
        precondition(messages.first { $0.remoteItemId == "new" }!.timelineItemOrder == 1)
        let local = ChatActions.addUserMessage(sessionId: session.id, text: "local", images: [], context: context)
        let assistant = ChatActions.beginAssistant(sessionId: session.id, context: context)
        precondition(local.timelineOrder == 3 && assistant.timelineOrder == 4)
        _ = ChatPlanActions.apply(
            itemId: "local-plan", text: "plan", delta: false, completed: true, seq: 1, sessionId: session.id,
            context: context)
        precondition(
            try! context.fetch(FetchDescriptor<ChatMessage>()).first { $0.remoteItemId == "local-plan" }!.timelineOrder
                == 5)
        let badOrder = await page([turn("a-latest", [text("last")]), turn("z-previous", [text("user")])])
        let beforeCount = try! context.fetchCount(FetchDescriptor<ChatMessage>())
        let rejectedOrder = await ChatActions.importPage(
            badOrder, direction: .newer, session: session, context: context)
        precondition(!rejectedOrder && (try! context.fetchCount(FetchDescriptor<ChatMessage>())) == beforeCount)
        let mismatch = ChatHistoryPage(
            threadId: "native",
            turns: [
                ChatHistoryTurn(id: "wrong", status: "completed", fullPayloadData: initial.turns[0].fullPayloadData)
            ], nextCursor: nil, backwardsCursor: nil)
        let mismatchOK = await ChatActions.importPage(mismatch, direction: .newer, session: session, context: context)
        precondition(!mismatchOK)
        for invalid in [
            ["threadId": "native", "data": [["items": [], "status": "completed"]]],
            ["threadId": "native", "data": [turn("id", [["type": "agentMessage"]])]],
            ["threadId": "native", "data": [turn("same", []), turn("same", [])]],
            ["threadId": "native", "data": [turn("id", [text("same"), text("same")])]],
            [
                "threadId": "native",
                "data": [["id": "id", "status": "completed", "itemsView": "summary", "items": []]],
            ],
            ["threadId": "native", "data": [], "nextCursor": ""],
        ] as [[String: Any]] {
            let decoded = await ChatHistoryPage.decode(try JSONSerialization.data(withJSONObject: invalid))
            precondition(decoded == nil)
        }
        try context.save()
        let privateContext = ModelContext(container)
        privateContext.autosaveEnabled = false
        let sid = session.id
        let privateSession = try privateContext.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == sid }))
            .first!
        let pending = await page([turn("uncommitted", [text("uncommitted-item")])])
        let cancelled = Task { @MainActor in
            await ChatActions.importPage(pending, direction: .newer, session: privateSession, context: privateContext)
        }
        cancelled.cancel()
        let cancelledResult = await cancelled.value
        precondition(!cancelledResult && !privateContext.hasChanges)
        var boundaryTask: Task<Bool, Never>?
        boundaryTask = Task { @MainActor in
            await ChatActions.importPage(
                pending, direction: .newer, session: privateSession, context: privateContext,
                beforeApply: {
                    boundaryTask?.cancel()
                    return !Task.isCancelled
                })
        }
        let boundaryResult = await boundaryTask!.value
        boundaryTask = nil
        precondition(!boundaryResult && !privateContext.hasChanges)
        let pendingOK = await ChatActions.importPage(
            pending, direction: .newer, session: privateSession, context: privateContext)
        precondition(pendingOK && privateContext.hasChanges)
        privateContext.rollback()
        let fresh = ModelContext(container)
        precondition(
            try! fresh.fetchCount(
                FetchDescriptor<ChatHistoryTurnRecord>(predicate: #Predicate { $0.turnId == "uncommitted" })) == 0)
        let migrated = Session(endpoint: endpoint)
        context.insert(migrated)
        let history: [String: Any] = [
            "turns": [turn("migration-old", [text("migration-a")]), turn("migration-new", [])]
        ]
        let migrationOK = await ChatActions.importHistory(
            history, session: migrated, context: context, recordTimeline: true)
        precondition(migrationOK)
        let migratedId = migrated.id
        precondition(
            try! context.fetchCount(
                FetchDescriptor<ChatHistoryTurnRecord>(predicate: #Predicate { $0.sessionId == migratedId })) == 2)
        let afterMigration = ChatActions.addUserMessage(
            sessionId: migrated.id, text: "after", images: [], context: context)
        precondition(afterMigration.timelineOrder >= 0)
        try context.save()
        var callbacks: [String] = []
        let gated = await page([turn("gated", [text("gated-message")])])
        let denied = await ChatActions.importPage(
            gated, direction: .newer, session: session, context: context,
            beforeApply: {
                callbacks.append("before")
                return false
            },
            afterApply: {
                callbacks.append("after")
                return true
            })
        precondition(!denied && callbacks == ["before"] && !context.hasChanges)
        callbacks = []
        session.title = "unsaved user title"
        let savedPage = await ChatActions.importPage(
            gated, direction: .newer, session: session, context: context,
            beforeApply: {
                callbacks.append("before")
                return (try? context.save()) != nil
            },
            afterApply: {
                callbacks.append("after")
                return (try? context.save()) != nil
            })
        precondition(savedPage && callbacks == ["before", "after"])
        let verify = ModelContext(container)
        precondition(
            try! verify.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == sid })).first!.title
                == "unsaved user title")
        let rollbackPage = await page([turn("rolled-back", [text("rolled-back-message")])])
        let rolledBack = await ChatActions.importPage(
            rollbackPage, direction: .newer, session: session, context: context,
            beforeApply: { (try? context.save()) != nil },
            afterApply: {
                context.rollback()
                return false
            })
        precondition(!rolledBack)
        precondition(
            try! context.fetchCount(
                FetchDescriptor<ChatHistoryTurnRecord>(predicate: #Predicate { $0.turnId == "rolled-back" })) == 0)
        let disconnected = await page([turn("disconnected", [text("disconnected-item")])])
        let disconnectedOK = await ChatActions.importPage(
            disconnected, direction: .initial, session: session, context: context)
        precondition(!disconnectedOK)
        let overlap = await page([turn("initial-new-tail", []), turn("gated", [text("gated-message")])])
        let overlapOK = await ChatActions.importPage(overlap, direction: .initial, session: session, context: context)
        precondition(overlapOK)
        let emptyOrder = try! context.fetch(
            FetchDescriptor<ChatHistoryTurnRecord>(predicate: #Predicate { $0.turnId == "initial-new-tail" })
        ).first!.order
        let afterEmpty = ChatActions.addUserMessage(
            sessionId: session.id, text: "after empty", images: [], context: context)
        precondition(afterEmpty.timelineOrder > emptyOrder)
        for malformed in [
            [String: Any](), ["turns": [["items": [], "status": "completed"]]],
            ["turns": [turn("bad", [["type": "agentMessage"]])]],
        ] {
            var called = false
            let invalidMigration = await ChatActions.importHistory(
                malformed, session: session, context: context,
                recordTimeline: true,
                beforeApply: {
                    called = true
                    return true
                })
            precondition(!invalidMigration && !called)
        }
        let newMigration = Session(endpoint: endpoint)
        context.insert(newMigration)
        var migrationCallbacks: [String] = []
        let atomicMigration = await ChatActions.importHistory(
            history, session: newMigration, context: context,
            recordTimeline: true,
            beforeApply: {
                migrationCallbacks.append("before")
                return (try? context.save()) != nil
            },
            afterApply: {
                migrationCallbacks.append("after")
                return (try? context.save()) != nil
            })
        precondition(atomicMigration && migrationCallbacks == ["before", "after"])
        user.imagesData = [Data()]
        let imageRace = await page([
            turn(
                "z-previous",
                [["id": "user", "type": "userMessage", "content": [["type": "localImage", "path": "/tmp/image.png"]]]])
        ])
        let racedImage = await ChatActions.importPage(
            imageRace, direction: .newer, session: session, context: context,
            beforeApply: {
                user.imagesData = [Data([8, 9])]
                return true
            })
        precondition(racedImage && user.imagesData == [Data([8, 9])])
        let obsoleteInitial = await ChatActions.importPage(
            initial, direction: .initial, session: session, context: context)
        precondition(!obsoleteInitial)
        let newId = newMigration.id
        ChatActions.discardHistory(sessionId: newId, context: context)
        precondition(
            try! context.fetchCount(
                FetchDescriptor<ChatHistoryTurnRecord>(predicate: #Predicate { $0.sessionId == newId })) == 0)
        let retrySession = Session(endpoint: endpoint)
        context.insert(retrySession)
        let retryId = retrySession.id
        let firstMigration = await ChatActions.importHistory(
            history, session: retrySession, context: context,
            recordTimeline: true, afterApply: { (try? context.save()) != nil })
        precondition(firstMigration)
        let firstRecords = try! context.fetch(
            FetchDescriptor<ChatHistoryTurnRecord>(
                predicate: #Predicate { $0.sessionId == retryId }, sortBy: [SortDescriptor(\.order)]))
        let firstOrders = firstRecords.map(\.order)
        let retryMessages = try! context.fetch(
            FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == retryId }))
        let firstMessageIds = Dictionary(uniqueKeysWithValues: retryMessages.map { ($0.remoteItemId!, $0.id) })
        let restarted = ModelContext(container)
        restarted.autosaveEnabled = false
        let recovered = try! restarted.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == retryId }))
            .first!
        let expanded: [String: Any] = [
            "turns": [
                turn("migration-old", [text("migration-a", "same turn updated")]), turn("migration-new", []),
                turn("appended-after-cursor-failure", [text("appended-item")]),
            ]
        ]
        let retryOK = await ChatActions.importHistory(
            expanded, session: recovered, context: restarted,
            recordTimeline: true, beforeApply: { (try? restarted.save()) != nil },
            afterApply: { (try? restarted.save()) != nil })
        precondition(retryOK)
        let recoveredRecords = try! restarted.fetch(
            FetchDescriptor<ChatHistoryTurnRecord>(
                predicate: #Predicate { $0.sessionId == retryId }, sortBy: [SortDescriptor(\.order)]))
        precondition(Array(recoveredRecords.prefix(2).map(\.order)) == firstOrders && recoveredRecords.count == 3)
        let recoveredMessages = try! restarted.fetch(
            FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == retryId }))
        precondition(recoveredMessages.first { $0.remoteItemId == "migration-a" }!.id == firstMessageIds["migration-a"])
        precondition(recoveredMessages.first { $0.remoteItemId == "appended-item" }!.timelineOrder > firstOrders.last!)
        for invalidTurns in [
            [turn("migration-new", []), turn("migration-old", [text("migration-a")])],
            [turn("migration-old", [text("migration-a")])],
            [turn("unrelated", [text("unrelated-item")])],
            [turn("prefix-insert", []), turn("migration-old", [text("migration-a")]), turn("migration-new", [])],
        ] {
            var admitted = false
            let invalidRetry = await ChatActions.importHistory(
                ["turns": invalidTurns], session: recovered, context: restarted,
                recordTimeline: true,
                beforeApply: {
                    admitted = true
                    return true
                })
            precondition(!invalidRetry && !admitted && !restarted.hasChanges)
        }
        let admittedSession = Session(endpoint: endpoint)
        context.insert(admittedSession)
        let admittedHistory: [String: Any] = ["turns": [turn("atomic", (0..<250).map { text("atomic-\($0)") })]]
        var admissionTask: Task<Bool, Never>?
        var finalized = false
        admissionTask = Task { @MainActor in
            await ChatActions.importHistory(
                admittedHistory, session: admittedSession, context: context,
                recordTimeline: true,
                beforeApply: {
                    admissionTask?.cancel()
                    return true
                },
                afterApply: {
                    finalized = true
                    return (try? context.save()) != nil
                })
        }
        let admittedResult = await admissionTask!.value
        admissionTask = nil
        precondition(admittedResult && finalized)
        let admittedId = admittedSession.id
        precondition(
            try! context.fetchCount(FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == admittedId }))
                == 250)
        let liveSession = Session(endpoint: endpoint)
        let otherSession = Session(endpoint: endpoint)
        context.insert(liveSession)
        context.insert(otherSession)
        let liveMessage = ChatMessage(sessionId: liveSession.id, role: .assistant)
        liveMessage.remoteItemId = "live-tool"
        liveMessage.remoteTurnId = "live-turn"
        liveMessage.hasToolCalls = true
        context.insert(liveMessage)
        let liveCall = ChatToolCall(
            id: "live-tool", messageId: liveMessage.id, sessionId: liveSession.id,
            name: "Bash", inputSummary: "pwd", inputJSON: "{}")
        context.insert(liveCall)
        let livePage = await page([
            turn(
                "live-turn",
                [
                    [
                        "id": "live-tool", "type": "commandExecution", "command": "pwd",
                        "status": "completed", "aggregatedOutput": "saved output", "exitCode": 0,
                    ]
                ])
        ])
        let adopted = await ChatActions.importPage(
            livePage, direction: .initial, session: liveSession, context: context)
        precondition(adopted)
        let repeatedLive = await ChatActions.importPage(
            livePage, direction: .initial, session: liveSession, context: context)
        precondition(repeatedLive)
        let isolated = await ChatActions.importPage(
            livePage, direction: .initial, session: otherSession, context: context)
        precondition(isolated)
        try context.save()
        let liveId = liveSession.id
        let adoptedCalls = try context.fetch(
            FetchDescriptor<ChatToolCall>(predicate: #Predicate { $0.sessionId == liveId }))
        let adoptedMessages = try context.fetch(
            FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == liveId }))
        precondition(adoptedCalls.count == 1 && adoptedCalls[0] === liveCall && liveCall.id == "live-tool")
        precondition(adoptedMessages.count == 1 && adoptedMessages[0].id == liveMessage.id)
        precondition(liveCall.result == "saved output" && liveCall.state == .succeeded)
        let otherId = otherSession.id
        let otherCalls = try context.fetch(
            FetchDescriptor<ChatToolCall>(predicate: #Predicate { $0.sessionId == otherId }))
        precondition(otherCalls.count == 1 && otherCalls[0].id == otherId.uuidString + ":live-tool")
        precondition(otherCalls[0].messageId != liveMessage.id && liveCall.sessionId == liveId)
        print(
            "PASS initial/older/newer server order, equal timestamps, empty turns, stable UUIDs, tool/image refresh, local plans/messages, malformed pages, cancellation, rollback and legacy migration"
        )
    }
}
