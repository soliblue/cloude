import Foundation

@main struct ChatInteractionTests {
    @MainActor static func main() async {
        let endpoint = Endpoint()
        let session = Session(endpoint: endpoint, path: "/repo")
        session.provider = .codex
        session.existsOnServer = true
        session.followsRemote = true
        session.remoteIsRunning = false
        let store = ChatInteractionStore.shared
        let request: [String: Any] = [
            "requestId": "child-approval", "method": "item/commandExecution/requestApproval",
            "params": ["command": "ls"],
        ]
        HTTPClient.getResponse = HTTPClient.response([])
        HTTPClient.beforeGet = {
            if HTTPClient.getCount == 1 { HTTPClient.getResponse = HTTPClient.response([request]) }
            if HTTPClient.getCount == 2 { session.followsRemote = false }
        }
        await ChatInteractionService.observe(session: session, interval: .milliseconds(1))
        precondition(HTTPClient.getCount == 2 && HTTPClient.postCount == 0)
        precondition(store.requests[session.id]?.first?.id == "child-approval" && session.needsAttention)
        HTTPClient.beforeGet = nil
        HTTPClient.getResponse = nil
        await ChatInteractionService.refresh(session: session)
        precondition(store.requests[session.id]?.count == 1)
        HTTPClient.getResponse = HTTPClient.response([])
        HTTPClient.beforeGet = {
            _ = store.add(
                ChatInteraction(
                    id: "new-live-request", method: "item/commandExecution/requestApproval", paramsJSON: "{}"),
                sessionId: session.id)
        }
        await ChatInteractionService.refresh(session: session)
        precondition(store.requests[session.id]?.count == 2)
        HTTPClient.beforeGet = { endpoint.connectionRevision = UUID() }
        HTTPClient.getResponse = HTTPClient.response([request.merging(["requestId": "stale"]) { _, next in next }])
        await ChatInteractionService.refresh(session: session)
        precondition(!store.requests[session.id]!.contains(where: { $0.id == "stale" }))
        HTTPClient.beforeGet = nil
        HTTPClient.postResponse = HTTPClient.response([])
        await ChatInteractionService.respond(
            session: session, request: store.requests[session.id]![0], result: ["decision": "accept"])
        precondition(HTTPClient.postCount == 1 && HTTPClient.lastBody["requestId"] as? String == "child-approval")
        precondition(store.requests[session.id]?.count == 1 && session.needsAttention)
        HTTPClient.getResponse = HTTPClient.response([])
        await ChatInteractionService.refresh(session: session)
        precondition(store.requests[session.id]?.isEmpty == true && !session.needsAttention)
        HTTPClient.getResponse = HTTPClient.response(
            [], agentAttention: [["threadId": "child-thread", "requestId": "opaque:99"]])
        await ChatInteractionService.refresh(session: session)
        precondition(
            store.requests[session.id]?.isEmpty == true
                && store.agentRequests[session.id]?.first?.threadId == "child-thread" && session.needsAttention)
        HTTPClient.getResponse = HTTPClient.response([])
        await ChatInteractionService.refresh(session: session)
        precondition(store.agentRequests[session.id]?.isEmpty == true && !session.needsAttention)
        let parentPollStart = HTTPClient.getCount
        HTTPClient.getResponse = HTTPClient.response(
            [], agentAttention: [["threadId": "child-thread", "requestId": "opaque:100"]])
        HTTPClient.beforeGet = {
            if HTTPClient.getCount == parentPollStart + 1 { HTTPClient.getResponse = HTTPClient.response([]) }
        }
        await ChatInteractionService.observe(session: session, interval: .milliseconds(1))
        precondition(HTTPClient.getCount == parentPollStart + 2 && !session.needsAttention)
        HTTPClient.beforeGet = nil
        session.followsRemote = true
        let before = HTTPClient.getCount
        let task = Task { await ChatInteractionService.observe(session: session, interval: .seconds(30)) }
        while HTTPClient.getCount == before { await Task.yield() }
        task.cancel()
        await task.value
        precondition(HTTPClient.getCount == before + 1)
        print(
            "PASS imported child approval polling independent of running status, explicit-only responses, offline retention, live revision precedence, connection fencing and cancellation"
        )
    }
}
