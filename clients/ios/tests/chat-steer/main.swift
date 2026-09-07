import Foundation
import SwiftData

@main struct SteerTests {
    @MainActor static func main() async throws {
        if CommandLine.arguments.count == 3 {
            try await durablePhase(CommandLine.arguments[1], path: CommandLine.arguments[2])
            return
        }
        let container = try ModelContainer(
            for: Session.self, Endpoint.self, ChatMessage.self, ChatHistoryTurnRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.autosaveEnabled = false
        let endpoint = Endpoint()
        let session = Session(endpoint: endpoint)
        context.insert(endpoint)
        context.insert(session)
        let message = ChatMessage(
            sessionId: session.id, role: .user, text: "Keep literal --flag \"quote\"", state: .queued)
        message.timelineOrder = 1
        message.timelineItemOrder = 12
        message.createdAt = Date(timeIntervalSince1970: 1)
        context.insert(message)
        let existingAssistant = ChatActions.beginAssistant(sessionId: session.id, context: context)
        precondition(existingAssistant.timelineOrder > message.timelineOrder)
        let nativeThreadId = session.codexThreadId
        session.codexThreadId = nil
        let callsBeforeInit = HTTPClient.bodies.count
        let beforeInit = await ChatService.steer(message: message, context: context)
        precondition(!beforeInit && HTTPClient.bodies.count == callsBeforeInit)
        precondition(message.steerRequestScope == nil && message.steerRequestPrompt == nil && message.state == .queued)
        session.codexThreadId = nativeThreadId
        let first = await ChatService.steer(message: message, context: context)
        precondition(
            !first && message.state == .queued && message.timelineOrder == 1 && message.timelineItemOrder == 12)
        precondition(message.createdAt == Date(timeIntervalSince1970: 1))
        var latestAssistant: ChatMessage?
        HTTPClient.beforeResponse = {
            latestAssistant = ChatActions.beginAssistant(sessionId: session.id, context: context)
        }
        HTTPClient.respond = true
        let retried = await ChatService.steer(message: message, context: context)
        precondition(retried && message.state == .complete)
        precondition(message.timelineOrder > latestAssistant!.timelineOrder && message.timelineItemOrder == 0)
        precondition(message.createdAt > Date(timeIntervalSince1970: 1))
        HTTPClient.beforeResponse = nil
        precondition(HTTPClient.bodies.count == 2)
        for body in HTTPClient.bodies {
            precondition(body["requestId"] as? String == message.id.uuidString)
            precondition(body["prompt"] as? String == message.text)
        }
        let repeated = await ChatService.steer(message: message, context: context)
        precondition(!repeated && HTTPClient.bodies.count == 2)
        let next = ChatMessage(sessionId: session.id, role: .user, text: "New steer", state: .queued)
        context.insert(next)
        let second = await ChatService.steer(message: next, context: context)
        precondition(second && HTTPClient.bodies.last?["requestId"] as? String == next.id.uuidString)
        let queued = ChatMessage(sessionId: session.id, role: .user, text: "first queued", state: .queued)
        queued.createdAt = Date(timeIntervalSince1970: 2)
        queued.timelineOrder = 1
        queued.timelineItemOrder = 9
        context.insert(queued)
        let laterQueued = ChatMessage(sessionId: session.id, role: .user, text: "later queued", state: .queued)
        laterQueued.createdAt = Date(timeIntervalSince1970: 3)
        laterQueued.timelineOrder = 1
        context.insert(laterQueued)
        let beforeDrain = ChatActions.beginAssistant(sessionId: session.id, context: context)
        ChatService.drainForTest(sessionId: session.id, context: context)
        precondition(queued.state == .queued && queued.timelineOrder == 1 && ChatService.beginnings.isEmpty)
        session.isStreaming = false
        ChatService.activeStreams.insert(session.id)
        ChatService.drainForTest(sessionId: session.id, context: context)
        precondition(queued.state == .queued && ChatService.beginnings.isEmpty)
        ChatService.activeStreams.remove(session.id)
        ChatService.drainForTest(sessionId: session.id, context: context)
        precondition(queued.state == .retrying && laterQueued.state == .queued)
        precondition(queued.timelineOrder > beforeDrain.timelineOrder && queued.timelineItemOrder == 0)
        precondition(
            ChatService.beginnings.last!.0 == queued.id && ChatService.beginnings.last!.1 == queued.timelineOrder)
        precondition(ChatService.beginnings.last!.3 == .retrying)
        precondition(ChatService.assistants.last!.timelineOrder > queued.timelineOrder)
        precondition(queued.createdAt > Date(timeIntervalSince1970: 2))
        let failed = ChatMessage(sessionId: session.id, role: .user, text: "failed retry", state: .failed)
        failed.timelineOrder = -5
        failed.timelineItemOrder = 8
        failed.createdAt = Date(timeIntervalSince1970: 4)
        context.insert(failed)
        let beforeRetry = ChatService.assistants.last!.timelineOrder
        ChatService.retry(message: failed, context: context)
        precondition(failed.state == .queued && failed.timelineOrder == -5 && failed.timelineItemOrder == 8)
        precondition(failed.createdAt == Date(timeIntervalSince1970: 4))
        failed.state = .failed
        session.isStreaming = false
        ChatService.retry(message: failed, context: context)
        precondition(failed.state == .retrying && failed.timelineOrder > beforeRetry && failed.timelineItemOrder == 0)
        precondition(
            ChatService.beginnings.last!.0 == failed.id && ChatService.beginnings.last!.1 == failed.timelineOrder)
        precondition(ChatService.assistants.last!.timelineOrder > failed.timelineOrder)
        precondition(failed.createdAt > Date(timeIntervalSince1970: 4))
        for change in ["endpoint", "path", "thread", "session-deletion", "message-deletion", "provider", "state"] {
            let scoped = Session(endpoint: endpoint)
            context.insert(scoped)
            let pending = ChatMessage(sessionId: scoped.id, role: .user, text: change, state: .queued)
            pending.timelineOrder = -100
            pending.timelineItemOrder = 14
            pending.createdAt = Date(timeIntervalSince1970: 10)
            context.insert(pending)
            HTTPClient.beforeResponse = {
                switch change {
                case "endpoint":
                    let replacement = Endpoint()
                    context.insert(replacement)
                    scoped.endpoint = replacement
                case "path": scoped.path = "/different"
                case "thread": scoped.codexThreadId = "different-thread"
                case "session-deletion": context.delete(scoped)
                case "message-deletion": context.delete(pending)
                case "provider": scoped.providerRaw = "claude"
                case "state": pending.state = .failed
                default: preconditionFailure()
                }
            }
            let stale = await ChatService.steer(message: pending, context: context)
            precondition(!stale)
            precondition(pending.state == (change == "state" ? .failed : .queued))
            precondition(pending.timelineOrder == -100 && pending.timelineItemOrder == 14)
            precondition(pending.createdAt == Date(timeIntervalSince1970: 10))
        }
        let cancelledSession = Session(endpoint: endpoint)
        context.insert(cancelledSession)
        let cancelledMessage = ChatMessage(sessionId: cancelledSession.id, role: .user, text: "cancel", state: .queued)
        cancelledMessage.timelineOrder = -200
        context.insert(cancelledMessage)
        var cancelledTask: Task<Bool, Never>?
        HTTPClient.beforeResponse = { cancelledTask?.cancel() }
        cancelledTask = Task { @MainActor in await ChatService.steer(message: cancelledMessage, context: context) }
        let cancelledResult = await cancelledTask!.value
        cancelledTask = nil
        precondition(!cancelledResult && cancelledMessage.state == .queued && cancelledMessage.timelineOrder == -200)
        let finishedSession = Session(endpoint: endpoint)
        context.insert(finishedSession)
        let finishedMessage = ChatMessage(
            sessionId: finishedSession.id, role: .user, text: "accepted before turn completed", state: .queued)
        context.insert(finishedMessage)
        HTTPClient.beforeResponse = { finishedSession.isStreaming = false }
        let finishedResult = await ChatService.steer(message: finishedMessage, context: context)
        precondition(finishedResult && finishedMessage.state == .complete)
        HTTPClient.beforeResponse = nil
        HTTPClient.receiptMode = true
        let raceSession = Session(endpoint: endpoint)
        context.insert(raceSession)
        let raceMessage = ChatMessage(sessionId: raceSession.id, role: .user, text: "deliver once", state: .queued)
        context.insert(raceMessage)
        let startsBefore = ChatService.beginnings.count
        HTTPClient.beforeResponse = {
            let saved = ModelContext(container)
            let id = raceMessage.id
            precondition(
                try! saved.fetch(FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.id == id })).first!
                    .steerRequestScope != nil)
            raceSession.isStreaming = false
            ChatService.drainForTest(sessionId: raceSession.id, context: context)
        }
        let raceAccepted = await ChatService.steer(message: raceMessage, context: context)
        precondition(raceAccepted && HTTPClient.dispatchedSteers == 1 && ChatService.beginnings.count == startsBefore)
        HTTPClient.beforeResponse = nil
        let ambiguousSession = Session(endpoint: endpoint)
        context.insert(ambiguousSession)
        let ambiguous = ChatMessage(sessionId: ambiguousSession.id, role: .user, text: "lost success", state: .queued)
        context.insert(ambiguous)
        HTTPClient.dropAcceptedResponse = true
        let ambiguousResult = await ChatService.steer(message: ambiguous, context: context)
        precondition(!ambiguousResult && ambiguous.steerRequestScope != nil)
        ambiguousSession.isStreaming = false
        ChatService.drainForTest(sessionId: ambiguousSession.id, context: context)
        precondition(ChatService.beginnings.count == startsBefore)
        HTTPClient.dropAcceptedResponse = false
        let dispatches = HTTPClient.dispatchedSteers
        endpoint.connectionRevision = UUID()
        let receiptRecovered = await ChatService.steer(message: ambiguous, context: context)
        precondition(receiptRecovered && ambiguous.state == .complete && ambiguous.steerRequestScope == nil)
        precondition(
            HTTPClient.dispatchedSteers == dispatches && HTTPClient.bodies.last?["receiptOnly"] as? Bool == true)
        let unsupportedSession = Session(endpoint: endpoint)
        context.insert(unsupportedSession)
        let unsupported = ChatMessage(sessionId: unsupportedSession.id, role: .user, text: "old host", state: .queued)
        unsupported.steerRequestScope = unsupportedSession.historyScopeKey
        unsupported.steerRequestPrompt = unsupported.text
        context.insert(unsupported)
        endpoint.capabilities = []
        let callsBefore = HTTPClient.bodies.count
        let oldHost = await ChatService.steer(message: unsupported, context: context)
        precondition(!oldHost && HTTPClient.bodies.count == callsBefore)
        endpoint.capabilities = ["codexSteerReceipts"]
        unsupportedSession.path = "/another-host-scope"
        let wrongScope = await ChatService.steer(message: unsupported, context: context)
        precondition(!wrongScope && HTTPClient.bodies.count == callsBefore)
        HTTPClient.receiptMode = false
        let storageDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storageDirectory) }
        let storageURL = storageDirectory.appendingPathComponent("readonly.store")
        let storageSchema = Schema([Session.self, Endpoint.self, ChatMessage.self, ChatHistoryTurnRecord.self])
        let seededContainer = try ModelContainer(
            for: storageSchema, configurations: [ModelConfiguration(schema: storageSchema, url: storageURL)])
        let seeded = ModelContext(seededContainer)
        let blockedEndpoint = Endpoint()
        let seededSession = Session(endpoint: blockedEndpoint)
        let seededMessage = ChatMessage(
            sessionId: seededSession.id, role: .user, text: "must save first", state: .queued)
        seeded.insert(blockedEndpoint)
        seeded.insert(seededSession)
        seeded.insert(seededMessage)
        try seeded.save()
        let readOnlyContainer = try ModelContainer(
            for: storageSchema,
            configurations: [ModelConfiguration(schema: storageSchema, url: storageURL, allowsSave: false)])
        let readOnly = ModelContext(readOnlyContainer)
        readOnly.autosaveEnabled = false
        let blockedMessage = try readOnly.fetch(FetchDescriptor<ChatMessage>()).first!
        let beforeBlocked = HTTPClient.bodies.count
        let blockedResult = await ChatService.steer(message: blockedMessage, context: readOnly)
        precondition(
            !blockedResult && blockedMessage.steerRequestScope == nil && HTTPClient.bodies.count == beforeBlocked)
        print(
            "PASS actual steering/retry/drain: failed requests preserve queued order, accepted prompts follow latest assistant, stable request IDs, active guards, oldest queue selection, prompt allocation before next assistant, stale endpoint/path/thread/deletion/provider/state/cancellation fences and accepted-turn completion"
        )
    }
    @MainActor static func durablePhase(_ phase: String, path: String) async throws {
        let schema = Schema([Session.self, Endpoint.self, ChatMessage.self, ChatHistoryTurnRecord.self])
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, url: URL(fileURLWithPath: path))])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        HTTPClient.receiptMode = true
        if phase == "--persist" {
            let endpoint = Endpoint()
            let session = Session(endpoint: endpoint)
            let message = ChatMessage(sessionId: session.id, role: .user, text: "survive app restart", state: .queued)
            context.insert(endpoint)
            context.insert(session)
            context.insert(message)
            HTTPClient.dropAcceptedResponse = true
            let result = await ChatService.steer(message: message, context: context)
            precondition(!result && message.steerRequestScope != nil && HTTPClient.dispatchedSteers == 1)
            session.isStreaming = false
            try context.save()
            print("PASS durable steer reservation saved before lost response")
        } else {
            let session = try context.fetch(FetchDescriptor<Session>()).first!
            let message = try context.fetch(FetchDescriptor<ChatMessage>()).first!
            precondition(message.steerRequestScope != nil && !session.isStreaming)
            ChatService.drainForTest(sessionId: session.id, context: context)
            precondition(ChatService.beginnings.isEmpty)
            HTTPClient.acceptedReceipts.insert(message.id.uuidString)
            let result = await ChatService.steer(message: message, context: context)
            precondition(result && message.state == .complete && message.steerRequestScope == nil)
            precondition(HTTPClient.dispatchedSteers == 0 && HTTPClient.bodies.count == 1)
            precondition(HTTPClient.bodies[0]["receiptOnly"] as? Bool == true)
            print("PASS separate-process restart recovers accepted receipt without any new dispatch")
        }
    }

}
