import Foundation
import SwiftData

@main struct EndpointActionsTests {
    @MainActor static func main() async throws {
        let container = try ModelContainer(
            for: Endpoint.self, Session.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let endpoint = EndpointActions.create(
            into: context, host: "original.invalid", port: 443,
            name: "Original", symbolName: "server.rack", authKey: "original-token")
        endpoint.capabilities = ["codex", "gitMutations"]
        endpoint.supportsCodex = true
        endpoint.daemonVersion = "fixture"
        let initialScope = endpoint.cacheId
        precondition(initialScope == endpoint.id)
        EndpointActions.update(
            endpoint, host: "original.invalid", port: 443, name: "Renamed",
            symbolName: "laptopcomputer", authKey: "original-token", scheme: "https")
        precondition(endpoint.name == "Renamed" && endpoint.supportsCodex == true)
        precondition(endpoint.cacheId == initialScope && HTTPClient.invalidated.isEmpty)
        precondition(ChatService.disconnectedHosts.isEmpty)
        EndpointActions.update(
            endpoint, host: "replacement.invalid", port: 443,
            symbolName: "laptopcomputer", authKey: "original-token", scheme: "https")
        let changedScope = endpoint.cacheId
        precondition(changedScope != initialScope && endpoint.capabilities == nil && endpoint.supportsCodex == nil)
        precondition(endpoint.daemonVersion == nil && endpoint.lastCheckReachable == nil)
        precondition(ChatService.disconnectedHosts == ["original.invalid"])
        precondition(HTTPClient.invalidated == [endpoint.id])
        for _ in 0..<100 { await Task.yield() }
        let initialRemoved = await FileCache.shared.removed.contains(initialScope)
        precondition(initialRemoved)
        let initialScheduleRemoved = await ScheduleCache.shared.removed.contains(initialScope)
        precondition(initialScheduleRemoved)
        precondition(SessionProjectService.removed.contains(initialScope))
        EndpointActions.update(
            endpoint, host: "replacement.invalid", port: 443,
            symbolName: "laptopcomputer", authKey: "rotated-token", scheme: "https")
        precondition(endpoint.cacheId != changedScope)
        precondition(SecureStorage.get(account: endpoint.id.uuidString) == "rotated-token")
        precondition(ChatService.disconnectedHosts == ["original.invalid", "replacement.invalid"])
        let session = Session(endpoint: endpoint)
        context.insert(session)
        let finalScope = endpoint.cacheId
        let endpointId = endpoint.id
        EndpointActions.remove(endpoint, context: context)
        precondition(session.endpoint == nil && ChatService.detached.contains(session.id))
        precondition(SecureStorage.get(account: endpointId.uuidString) == nil)
        for _ in 0..<100 { await Task.yield() }
        let finalRemoved = await FileCache.shared.removed.contains(finalScope)
        precondition(finalRemoved)
        let finalScheduleRemoved = await ScheduleCache.shared.removed.contains(finalScope)
        precondition(finalScheduleRemoved)
        precondition(SessionProjectService.removed.contains(finalScope))
        print(
            "Endpoint actions: cosmetic edits preserve connection, transport/token edits detach old transport before mutation, cache scopes rotate, deletion detaches sessions and purges scoped data passed"
        )
    }
}
