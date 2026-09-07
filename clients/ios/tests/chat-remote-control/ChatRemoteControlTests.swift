import Foundation
import SwiftData

@main struct ChatRemoteControlTests {
    @MainActor static func main() async throws {
        let container = try ModelContainer(
            for: Session.self, Endpoint.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let endpoint = Endpoint()
        let session = Session(endpoint: endpoint, path: "/repo")
        container.mainContext.insert(session)
        session.provider = .codex
        session.followsRemote = true
        session.remoteIsRunning = true
        let store = ChatRemoteControlStore()
        HTTPClient.beforeResponse = {
            await ChatRemoteControlService.stop(session: session, context: container.mainContext, store: store)
        }
        await ChatRemoteControlService.stop(session: session, context: container.mainContext, store: store)
        precondition(HTTPClient.count == 1 && session.remoteIsRunning && !session.isStreaming && session.followsRemote)
        precondition(
            store.requested.contains(session.id) && !store.submitting.contains(session.id)
                && SessionRemoteFollowService.refreshes == 1)
        HTTPClient.beforeResponse = nil
        HTTPClient.status = 502
        await ChatRemoteControlService.stop(session: session, context: container.mainContext, store: store)
        precondition(
            session.remoteIsRunning && store.errors[session.id] != nil && SessionRemoteFollowService.refreshes == 1)
        HTTPClient.status = 200
        SessionRemoteFollowService.confirmsStopped = true
        await ChatRemoteControlService.stop(session: session, context: container.mainContext, store: store)
        precondition(!session.remoteIsRunning && !store.requested.contains(session.id))
        session.remoteIsRunning = true
        store.clear(sessionId: session.id)
        HTTPClient.beforeResponse = { endpoint.connectionRevision = UUID() }
        await ChatRemoteControlService.stop(session: session, context: container.mainContext, store: store)
        precondition(
            session.remoteIsRunning && !store.requested.contains(session.id) && store.errors[session.id] == nil)
        store.clear(sessionId: session.id)
        HTTPClient.beforeResponse = nil
        let count = HTTPClient.count
        session.provider = .claude
        await ChatRemoteControlService.stop(session: session, context: container.mainContext, store: store)
        precondition(HTTPClient.count == count)
        print(
            "PASS remote Stop single explicit request, no optimistic completion/resend, authoritative history confirmation, failure retry and connection/provider guards"
        )
    }
}
