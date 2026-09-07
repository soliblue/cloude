import Foundation
import SwiftData

struct ForkRetryTests {
    @MainActor static func run() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for mode in ["fork-write", "fork-read", "fork-readonly"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            process.arguments = [mode, directory.path]
            try process.run()
            process.waitUntilExit()
            precondition(process.terminationStatus == 0, mode)
        }
        let container = try ModelContainer(
            for: Endpoint.self, Session.self, Window.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let endpoint = Endpoint()
        endpoint.capabilities = ["codexActiveFork", "codexIdempotentFork"]
        context.insert(endpoint)
        let source = Session(endpoint: endpoint, path: "/repo")
        source.codexThreadId = "parent-thread"
        context.insert(source)
        HTTPClient.postPaths = []
        HTTPClient.postBodies = []
        HTTPClient.postResponse = response()
        var release: CheckedContinuation<Void, Never>?
        HTTPClient.beforePost = { _ in await withCheckedContinuation { release = $0 } }
        ChatActions.beforeImport = {
            precondition((try? context.fetchCount(FetchDescriptor<Session>())) == 1, "Partial fork must stay invisible")
        }
        let first = Task { @MainActor in
            await SessionForkService.fork(session: source, context: context, store: SessionForkStore())
        }
        while release == nil { await Task.yield() }
        let pendingId = source.pendingForkId!
        let secondStore = SessionForkStore()
        let second = Task { @MainActor in
            await SessionForkService.fork(session: source, context: context, store: secondStore)
        }
        while !secondStore.isForking { await Task.yield() }
        precondition(HTTPClient.postPaths.count == 1)
        release?.resume()
        let results = await (first.value, second.value)
        precondition(results.0 && results.1)
        precondition(
            HTTPClient.postBodies.count == 1
                && HTTPClient.postBodies[0]["newSessionId"] as? String == pendingId.uuidString)
        precondition((try? context.fetchCount(FetchDescriptor<Window>())) == 1)
        precondition((try? context.fetchCount(FetchDescriptor<Session>())) == 2)
        precondition(source.pendingForkId == nil)
        HTTPClient.beforePost = nil
        ChatActions.beforeImport = nil
        print("PASS concurrent side-chat attempts share one request and publish only fully imported history")
        HTTPClient.postPaths = []
        HTTPClient.beforePost = { _ in await withCheckedContinuation { release = $0 } }
        release = nil
        let canceled = Task { @MainActor in
            await SessionForkService.fork(session: source, context: context, store: SessionForkStore())
        }
        while release == nil { await Task.yield() }
        let survivorStore = SessionForkStore()
        let survivor = Task { @MainActor in
            await SessionForkService.fork(session: source, context: context, store: survivorStore)
        }
        while !survivorStore.isForking { await Task.yield() }
        canceled.cancel()
        for _ in 0..<5 { await Task.yield() }
        release?.resume()
        let shared = await (canceled.value, survivor.value)
        precondition(!shared.0 && shared.1 && HTTPClient.postPaths.count == 1)
        precondition(source.pendingForkId == nil)
        HTTPClient.beforePost = nil
        print("PASS a canceled waiter does not cancel another caller's shared side-chat request")
        for code in ["fork_outcome_unknown", "fork_pending", "fork_storage_error", "fork_conflict"] {
            HTTPClient.postResponse = (
                try JSONSerialization.data(withJSONObject: [
                    "error": "Host failure", "code": code,
                    "retriable": code == "fork_pending" || code == "fork_storage_error",
                ]),
                HTTPURLResponse(
                    url: URL(string: "http://fixture")!, statusCode: 409, httpVersion: nil, headerFields: nil)!
            )
            let store = SessionForkStore()
            let failed = await SessionForkService.fork(session: source, context: context, store: store)
            precondition(!failed)
            let failedId = source.pendingForkId!
            precondition((store.unconfirmedRequestId == failedId) == (code == "fork_outcome_unknown"))
            let retry = await SessionForkService.fork(session: source, context: context, store: store)
            precondition(!retry && source.pendingForkId == failedId)
            HTTPClient.postResponse = response()
            let recovered = await SessionForkService.fork(
                session: source, context: context, store: store, startAnother: true)
            precondition(recovered)
            let sent = HTTPClient.postBodies.last?["newSessionId"] as? String
            precondition((sent != failedId.uuidString) == (code == "fork_outcome_unknown"))
            precondition(source.pendingForkId == nil && store.unconfirmedRequestId == nil)
        }
        print(
            "PASS uncertain forks retain their request until explicitly replaced; pending/storage/conflict retries cannot start duplicates"
        )
    }

    @MainActor static func stage(_ mode: String, directory: URL) async throws {
        let container = try ModelContainer(
            for: Endpoint.self, Session.self, Window.self,
            configurations: ModelConfiguration(
                url: directory.appendingPathComponent("state.store"), allowsSave: mode != "fork-readonly"))
        let context = container.mainContext
        HTTPClient.postPaths = []
        HTTPClient.postBodies = []
        HTTPClient.beforePost = nil
        ChatActions.beforeImport = nil
        ChatActions.importResult = true
        if mode == "fork-write" {
            let endpoint = Endpoint()
            endpoint.capabilities = ["codexActiveFork", "codexIdempotentFork"]
            context.insert(endpoint)
            let source = Session(endpoint: endpoint, path: "/repo")
            source.codexThreadId = "parent-thread"
            context.insert(source)
            HTTPClient.postResponse = nil
            let result = await SessionForkService.fork(session: source, context: context, store: SessionForkStore())
            precondition(!result && source.pendingForkId != nil && HTTPClient.postPaths.count == 1)
            try JSONSerialization.data(withJSONObject: [
                "source": source.id.uuidString, "request": source.pendingForkId!.uuidString,
            ])
            .write(to: directory.appendingPathComponent("expected.json"))
            print("PASS lost-response attempt saved before POST and retained")
        } else {
            let expected =
                try JSONSerialization.jsonObject(
                    with: Data(contentsOf: directory.appendingPathComponent("expected.json"))) as! [String: String]
            let sourceId = UUID(uuidString: expected["source"]!)!
            let source = try context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == sourceId })).first!
            HTTPClient.postResponse = response()
            let store = SessionForkStore()
            if mode == "fork-read" {
                precondition(source.pendingForkId?.uuidString == expected["request"])
                let stableScope = source.forkScopeKey
                source.endpoint?.connectionRevision = UUID()
                precondition(source.forkScopeKey == stableScope)
                ChatActions.beforeImport = {
                    precondition(
                        (try? context.fetchCount(FetchDescriptor<Session>())) == 1,
                        "Uncommitted history must remain private")
                }
                let result = await SessionForkService.fork(session: source, context: context, store: store)
                precondition(result && source.pendingForkId == nil)
                precondition(HTTPClient.postBodies.first?["newSessionId"] as? String == expected["request"])
                let requestId = UUID(uuidString: expected["request"]!)!
                let fork = try context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == requestId }))
                    .first!
                precondition(
                    fork.codexThreadId == "retry-thread" && fork.parentSessionId == source.id && fork.followsRemote)
                print(
                    "PASS new process and credential revision recover identical request ID and commit fork before clearing attempt"
                )
            } else {
                precondition(source.pendingForkId == nil)
                let result = await SessionForkService.fork(session: source, context: context, store: store)
                precondition(!result && HTTPClient.postPaths.isEmpty && store.error?.contains("storage") == true)
                print("PASS read-only phone store blocks remote fork before POST")
            }
        }
    }

    static func response() -> (Data, HTTPURLResponse) {
        (
            Data(
                #"{"threadId":"retry-thread","thread":{"id":"retry-thread","cwd":"/repo","status":{"type":"idle"},"turns":[{"id":"done","status":"completed","items":[]}]}}"#
                    .utf8),
            HTTPURLResponse(url: URL(string: "http://fixture")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
    }
}
