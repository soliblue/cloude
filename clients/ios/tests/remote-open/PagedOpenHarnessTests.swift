import Foundation
import SwiftData

enum PagedOpenHarnessTests {
    @MainActor static func run() async throws {
        HTTPClient.beforeGet = nil
        HTTPClient.beforePost = nil
        defer {
            SessionHistoryPageService.beforePrepare = nil
            SessionHistoryPageService.prepareResult = false
        }
        for scenario in ["success", "cancellation", "revision", "failure", "concurrent", "endpointMetadata"] {
            let container = try ModelContainer(
                for: Endpoint.self, Session.self, Window.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let context = container.mainContext
            let endpoint = Endpoint()
            endpoint.capabilities = ["codexHistoryPages"]
            context.insert(endpoint)
            let thread = try JSONDecoder().decode(
                SessionRemoteThread.self,
                from: Data(
                    #"{"id":"paged-thread","cwd":"/paged-repo","preview":"Paged task","name":"Paged task","updatedAt":1}"#
                        .utf8))
            HTTPClient.postResponse = (
                Data(
                    #"{"thread":{"id":"paged-thread","cwd":"/paged-repo","preview":"Paged task","name":"Paged task","updatedAt":1}}"#
                        .utf8),
                HTTPURLResponse(
                    url: URL(string: "http://fixture")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
            HTTPClient.postBodies = []
            HTTPClient.postPaths = []
            SessionHistoryPageService.prepareResult = scenario != "failure"
            var releases: [CheckedContinuation<Void, Never>] = []
            var preparedIds: [UUID] = []
            SessionHistoryPageService.beforePrepare = { session, metadata, transaction, transport in
                precondition(transaction !== context && !transaction.autosaveEnabled)
                precondition(session.modelContext === transaction && session.endpoint !== endpoint)
                precondition(transport === endpoint)
                precondition(session.endpoint?.id == endpoint.id && metadata["id"] as? String == thread.id)
                precondition(metadata["turns"] == nil)
                session.title = "Prepared page"
                preparedIds.append(session.id)
                await withCheckedContinuation { releases.append($0) }
                if scenario == "endpointMetadata" {
                    transport?.capabilities = ["codexHistoryPages", "responseCapability"]
                    precondition(session.endpoint?.capabilities == ["codexHistoryPages"])
                    precondition(session.endpoint?.host == "fixture")
                }
            }
            let stores = (0..<(scenario == "concurrent" ? 2 : 1)).map { _ in SessionRemoteStore() }
            let tasks = stores.map { store in
                Task { @MainActor in
                    await SessionRemoteService.open(thread, endpoint: endpoint, store: store, context: context)
                }
            }
            let deadline = Date().addingTimeInterval(10)
            while releases.count < tasks.count && Date() < deadline { await Task.yield() }
            precondition(releases.count == tasks.count, "Paged open did not reach preparation: \(scenario)")
            precondition((try? context.fetchCount(FetchDescriptor<Session>())) == 0)
            precondition((try? context.fetchCount(FetchDescriptor<Window>())) == 0)
            precondition((try? ModelContext(container).fetchCount(FetchDescriptor<Session>())) == 0)
            precondition(HTTPClient.postBodies.count == tasks.count)
            precondition(HTTPClient.postPaths.allSatisfy { $0.hasSuffix("/import") })
            precondition(
                HTTPClient.postBodies.allSatisfy {
                    $0.count == 2 && $0["threadId"] as? String == thread.id && $0["includeTurns"] as? Bool == false
                })
            if scenario == "cancellation" { tasks[0].cancel() }
            if scenario == "revision" { endpoint.connectionRevision = UUID() }
            if scenario == "endpointMetadata" {
                endpoint.host = "user-renamed-host"
                try context.save()
            }
            for release in releases { release.resume() }
            var results: [Bool] = []
            for task in tasks { results.append(await task.value) }
            let succeeds = scenario == "success" || scenario == "concurrent" || scenario == "endpointMetadata"
            precondition(results.allSatisfy { $0 == succeeds }, "Unexpected result: \(scenario)")
            let sessions = try context.fetch(FetchDescriptor<Session>())
            let windows = try context.fetch(FetchDescriptor<Window>())
            precondition(sessions.count == (succeeds ? 1 : 0), "Session count \(sessions.count): \(scenario)")
            precondition(windows.count == (succeeds ? 1 : 0), "Window count \(windows.count): \(scenario)")
            if scenario == "endpointMetadata" {
                precondition(endpoint.capabilities == ["codexHistoryPages", "responseCapability"])
                precondition(
                    (try? ModelContext(container).fetch(FetchDescriptor<Endpoint>()).first?.host) == "user-renamed-host"
                )
            }
            if succeeds {
                precondition(preparedIds.contains(sessions[0].id) && windows[0].session?.id == sessions[0].id)
                precondition(sessions[0].title == "Prepared page" && sessions[0].codexThreadId == thread.id)
                precondition(sessions[0].path == thread.cwd && sessions[0].endpoint?.id == endpoint.id)
                precondition(stores.allSatisfy { $0.openingId == nil && $0.openingScope == nil })
                let reused = await SessionRemoteService.open(
                    threadId: thread.id, endpoint: endpoint, store: stores[0], context: context)
                precondition(reused && HTTPClient.postBodies.count == tasks.count)
                precondition((try? context.fetchCount(FetchDescriptor<Window>())) == 1)
            }
            try context.save()
            precondition((try? ModelContext(container).fetchCount(FetchDescriptor<Session>())) == (succeeds ? 1 : 0))
            precondition((try? ModelContext(container).fetchCount(FetchDescriptor<Window>())) == (succeeds ? 1 : 0))
            if scenario == "endpointMetadata" {
                let saved = try ModelContext(container).fetch(FetchDescriptor<Endpoint>()).first!
                precondition(saved.host == "user-renamed-host")
                precondition(saved.capabilities == ["codexHistoryPages", "responseCapability"])
            }
        }
        print(
            "Paged remote opening passed private publication, metadata-only import, cancellation, revision, failure, concurrent reuse and transport metadata isolation"
        )
    }
}
