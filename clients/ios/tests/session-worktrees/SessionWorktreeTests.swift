import Foundation
import SwiftData

@main struct SessionWorktreeTests {
    @MainActor static func main() async {
        let container = try! ModelContainer(
            for: Session.self, Endpoint.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let endpoint = Endpoint()
        let source = Session(endpoint: endpoint, path: "/home/me/repo", title: "Existing work")
        source.provider = .codex
        source.modelRaw = "gpt-5.5"
        source.effort = .high
        source.permissionMode = .plan
        source.existsOnServer = true
        source.codexThreadId = "old-thread"
        source.codexProjectId = "old-project"
        source.isStreaming = true
        source.lastSeq = 55
        context.insert(source)
        let store = SessionWorktreeStore()
        HTTPClient.set([
            "branches": [["name": "feature", "current": true], ["name": "feature", "current": true]],
            "defaultBranch": "origin/main",
        ])
        await SessionWorktreeService.load(session: source, store: store)
        precondition(store.baseRef == "origin/main" && store.branches.count == 2)
        precondition(HTTPClient.query["path"] == source.path)
        store.branch = "feature"
        precondition(!store.canCreate)
        store.branch = "bad branch"
        precondition(!store.canCreate)
        store.branch = " afto/new-task "
        precondition(store.canCreate)
        HTTPClient.response = nil
        let result1 = await SessionWorktreeService.create(session: source, store: store, context: context)
        precondition(result1 == nil)
        let requestId = HTTPClient.body["requestId"] as! String
        precondition(store.error != nil && !store.isCreating && store.canCreate)
        HTTPClient.set([
            "path": "/home/me/.worktrees/actual-generated-path", "branch": "afto/new-task", "head": "abc123",
        ])
        HTTPClient.beforeResponse = {
            let nested = await SessionWorktreeService.create(session: source, store: store, context: context)
            precondition(nested == nil)
        }
        let created = await SessionWorktreeService.create(session: source, store: store, context: context)!
        HTTPClient.beforeResponse = nil
        precondition(HTTPClient.body["requestId"] as? String == requestId)
        precondition(HTTPClient.body["baseRef"] as? String == "origin/main")
        precondition(created.path == "/home/me/.worktrees/actual-generated-path")
        precondition(created.endpoint?.id == endpoint.id && created.provider == source.provider)
        precondition(created.model == source.model && created.effort == .high && created.permissionMode == .plan)
        precondition(created.codexThreadId == nil && created.codexProjectId == nil && created.parentSessionId == nil)
        precondition(!created.existsOnServer && !created.isStreaming && created.lastSeq == -1)
        precondition(
            source.path == "/home/me/repo" && source.title == "Existing work" && source.codexThreadId == "old-thread"
                && source.lastSeq == 55 && source.isStreaming)
        let previousCalls = HTTPClient.calls
        let repeatCreated = await SessionWorktreeService.create(session: source, store: store, context: context)
        precondition(repeatCreated?.id == created.id)
        precondition(HTTPClient.calls == previousCalls)
        precondition(try! context.fetchCount(FetchDescriptor<Session>()) == 2)
        let newStore = SessionWorktreeStore()
        newStore.apply(
            SessionWorktreeBranches(branches: [SessionWorktreeBranch(name: "main", current: true)], defaultBranch: nil))
        newStore.branch = "new"
        let firstId = newStore.prepareRequest(path: "/repo")
        precondition(newStore.prepareRequest(path: "/repo") == firstId)
        newStore.branch = "another"
        precondition(newStore.prepareRequest(path: "/repo") != firstId)
        HTTPClient.set(["error": "Branch already exists"], status: 409)
        let result2 = await SessionWorktreeService.create(session: source, store: newStore, context: context)
        precondition(result2 == nil)
        precondition(newStore.error == "Branch already exists")
        HTTPClient.set(["path": "relative", "branch": "another", "head": "abc"])
        let result3 = await SessionWorktreeService.create(session: source, store: newStore, context: context)
        precondition(result3 == nil)
        precondition(try! context.fetchCount(FetchDescriptor<Session>()) == 2)
        HTTPClient.beforeResponse = { store.generation = UUID() }
        HTTPClient.set(["branches": [["name": "stale", "current": true]]])
        await SessionWorktreeService.load(session: source, store: store)
        precondition(!store.branches.contains(where: { $0.name == "stale" }))
        HTTPClient.beforeResponse = { endpoint.connectionRevision = UUID() }
        HTTPClient.set(["path": "/worktrees/another", "branch": "another", "head": "abc"])
        let changedConnection = await SessionWorktreeService.create(session: source, store: newStore, context: context)
        precondition(changedConnection == nil && (try! context.fetchCount(FetchDescriptor<Session>())) == 2)
        HTTPClient.beforeResponse = { source.endpoint = nil }
        HTTPClient.set(["path": "/worktrees/another", "branch": "another", "head": "abc"])
        let result4 = await SessionWorktreeService.create(session: source, store: newStore, context: context)
        precondition(result4 == nil)
        precondition(try! context.fetchCount(FetchDescriptor<Session>()) == 2)
        print(
            "PASS worktree branch selection, remote defaults, request retries, actual path, settings preservation, source isolation, duplicate prevention, errors and endpoint removal"
        )
    }
}
