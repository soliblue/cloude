import Foundation
import SwiftData

@main struct SessionCompactionTests {
    @MainActor static func main() async {
        let container = try! ModelContainer(
            for: Session.self, Endpoint.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let endpoint = Endpoint()
        let session = Session(endpoint: endpoint, path: "/repo", title: "Original task")
        session.provider = .codex
        session.existsOnServer = true
        session.codexThreadId = "thread"
        session.contextTokens = 85000
        session.contextWindow = 128000
        session.lastSeq = 40
        context.insert(session)
        let store = SessionCompactionStore()
        HTTPClient.getResponse = HTTPClient.response(["status": "idle", "threadId": "thread"])
        await SessionCompactionService.refresh(session: session, store: store, context: context)
        precondition(store.canStart(session: session) && HTTPClient.postCount == 0)
        session.isStreaming = true
        await SessionCompactionService.start(session: session, store: store, context: context)
        precondition(HTTPClient.postCount == 0)
        session.isStreaming = false
        session.remoteIsRunning = true
        precondition(!store.canStart(session: session))
        session.remoteIsRunning = false
        HTTPClient.postResponse = HTTPClient.response(["status": "pending", "threadId": "thread"], status: 202)
        HTTPClient.beforePost = {
            await SessionCompactionService.start(session: session, store: store, context: context)
        }
        await SessionCompactionService.start(session: session, store: store, context: context)
        HTTPClient.beforePost = nil
        precondition(store.isPending && HTTPClient.postCount == 1 && !store.canStart(session: session))
        precondition(session.contextTokens == 85000 && session.title == "Original task")
        HTTPClient.getResponse = nil
        await SessionCompactionService.refresh(session: session, store: store, context: context)
        precondition(store.isPending && store.error != nil && session.contextTokens == 85000)
        HTTPClient.getResponse = HTTPClient.response([
            "status": "completed", "threadId": "thread", "contextTokens": 17000, "contextWindow": 128000,
        ])
        await SessionCompactionService.refresh(session: session, store: store, context: context)
        precondition(store.snapshot?.status == "completed" && session.contextTokens == 17000)
        HTTPClient.beforeGet = {
            session.lastSeq += 1
            session.contextTokens = 23000
        }
        await SessionCompactionService.refresh(session: session, store: store, context: context)
        precondition(session.contextTokens == 23000)
        HTTPClient.beforeGet = nil
        HTTPClient.getResponse = HTTPClient.response(["status": "completed", "threadId": "thread"])
        await SessionCompactionService.refresh(session: session, store: store, context: context)
        precondition(session.contextTokens == 23000 && session.contextWindow == 128000)
        HTTPClient.getResponse = HTTPClient.response(["status": "completed", "threadId": "other", "contextTokens": 1])
        await SessionCompactionService.refresh(session: session, store: store, context: context)
        precondition(session.contextTokens == 23000 && store.error != nil)
        HTTPClient.getResponse = HTTPClient.response(["status": "idle", "threadId": "thread"])
        await SessionCompactionService.refresh(session: session, store: store, context: context)
        HTTPClient.postResponse = nil
        HTTPClient.getResponse = nil
        await SessionCompactionService.start(session: session, store: store, context: context)
        precondition(store.uncertainStart && !store.canStart(session: session))
        HTTPClient.getResponse = HTTPClient.response(["status": "pending", "threadId": "thread"])
        await SessionCompactionService.refresh(session: session, store: store, context: context)
        precondition(!store.uncertainStart && store.isPending)
        HTTPClient.getResponse = HTTPClient.response([
            "status": "failed", "threadId": "thread", "error": "Compaction interrupted",
        ])
        await SessionCompactionService.refresh(session: session, store: store, context: context)
        precondition(store.error == "Compaction interrupted" && store.canStart(session: session))
        HTTPClient.postResponse = HTTPClient.response(["error": "Finish the active turn first"], status: 409)
        await SessionCompactionService.start(session: session, store: store, context: context)
        precondition(store.error == "Finish the active turn first" && !store.isStarting)
        HTTPClient.getResponse = HTTPClient.response(["status": "completed", "threadId": "thread", "contextTokens": 3])
        HTTPClient.beforeGet = { store.invalidate() }
        await SessionCompactionService.refresh(session: session, store: store, context: context)
        precondition(session.contextTokens == 23000 && store.snapshot?.status == "failed")
        HTTPClient.beforeGet = { session.endpoint = nil }
        await SessionCompactionService.refresh(session: session, store: store, context: context)
        precondition(session.contextTokens == 23000 && !store.canStart(session: session))
        precondition(session.path == "/repo" && session.codexThreadId == "thread")
        print(
            "PASS explicit compaction, active/duplicate guards, pending202, offline progress, confirmed usage, stale sequence/thread/endpoint/disappearance, uncertain-start recovery and actionable409"
        )
    }
}
