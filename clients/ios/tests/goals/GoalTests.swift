import Foundation
import SwiftData

@main struct GoalTests {
    @MainActor static func main() async throws {
        let container = try ModelContainer(
            for: Session.self, Endpoint.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let endpoint = Endpoint()
        container.mainContext.insert(endpoint)
        let session = Session(endpoint: endpoint)
        container.mainContext.insert(session)
        let goal: [String: Any] = [
            "objective": "Ship the feature", "status": "active", "tokenBudget": 50000, "tokensUsed": 120,
            "timeUsedSeconds": 45,
        ]
        HTTPClient.response = (
            try JSONSerialization.data(withJSONObject: ["goal": goal]),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        let loaded = await ChatGoalService.refresh(session: session)
        precondition(loaded && session.goal?.objective == "Ship the feature" && session.goal?.tokenBudget == 50000)
        HTTPClient.response = nil
        let offline = await ChatGoalService.refresh(session: session)
        precondition(!offline && session.goal?.tokensUsed == 120)
        let failedSave = await ChatGoalService.set(session: session, body: ["objective": "Changed"])
        precondition(!failedSave && session.goal?.objective == "Ship the feature")
        HTTPClient.response = (
            try JSONSerialization.data(withJSONObject: ["goal": goal]),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        let saved = await ChatGoalService.set(
            session: session, body: ["objective": "Ship the feature", "tokenBudget": NSNull()])
        precondition(saved && HTTPClient.lastBody["tokenBudget"] is NSNull)
        precondition(URLProtocol.registerClass(GoalURLProtocol.self))
        GoalURLProtocol.status = 401
        let rejectedClear = await ChatGoalService.clear(session: session)
        precondition(!rejectedClear && session.goal != nil)
        GoalURLProtocol.status = 200
        let cleared = await ChatGoalService.clear(session: session)
        precondition(cleared && session.goal == nil)
        precondition(GoalURLProtocol.captured?.httpMethod == "DELETE")
        precondition(GoalURLProtocol.captured?.value(forHTTPHeaderField: "Authorization") == "Bearer test")
        URLProtocol.unregisterClass(GoalURLProtocol.self)
        HTTPClient.response = (
            try JSONSerialization.data(withJSONObject: ["goal": goal]),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        var releaseRefresh: CheckedContinuation<Void, Never>?
        HTTPClient.beforeGetResponse = { await withCheckedContinuation { releaseRefresh = $0 } }
        let staleRefresh = Task { @MainActor in await ChatGoalService.refresh(session: session) }
        while releaseRefresh == nil { await Task.yield() }
        var changedGoal = goal
        changedGoal["objective"] = "New saved objective"
        HTTPClient.response = (
            try JSONSerialization.data(withJSONObject: ["goal": changedGoal]),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        let newerSave = await ChatGoalService.set(session: session, body: ["objective": "New saved objective"])
        precondition(newerSave)
        releaseRefresh?.resume()
        let oldRefreshApplied = await staleRefresh.value
        HTTPClient.beforeGetResponse = nil
        precondition(!oldRefreshApplied && session.goal?.objective == "New saved objective")
        let mutation = ChatGoalRequestStore.begin(sessionId: session.id, mutating: true)!
        let callsBefore = HTTPClient.calls
        let blockedRefresh = await ChatGoalService.refresh(session: session)
        precondition(!blockedRefresh && HTTPClient.calls == callsBefore)
        precondition(ChatGoalRequestStore.finish(mutation, sessionId: session.id))
        print("Passed stale goal refresh rejection and mutation priority")
        print(
            "Passed goal loading, offline preservation, failed mutation preservation, optional budget, and authenticated clear"
        )
    }
}
