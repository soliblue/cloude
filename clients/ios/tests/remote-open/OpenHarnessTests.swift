import Foundation
import SwiftData

@main
struct OpenHarnessTests {
    @MainActor static func main() async throws {
        let container = try ModelContainer(
            for: Endpoint.self, Session.self, Window.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let endpoint = Endpoint()
        context.insert(endpoint)
        let store = SessionRemoteStore()
        let thread = try JSONDecoder().decode(
            SessionRemoteThread.self,
            from: Data(
                #"{"id":"thread-1","cwd":"/repo","preview":"Task","name":"Task","updatedAt":1,"agentNickname":null,"agentPath":null}"#
                    .utf8))
        let detail = try JSONSerialization.data(withJSONObject: [
            "thread": [
                "id": thread.id, "cwd": thread.cwd, "preview": thread.preview, "name": thread.name as Any,
                "updatedAt": thread.updatedAt, "agentNickname": thread.agentNickname as Any,
                "agentPath": thread.agentPath as Any,
            ]
        ])
        HTTPClient.getResponse = (
            detail,
            HTTPURLResponse(url: URL(string: "http://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        HTTPClient.postResponse = (
            try JSONSerialization.data(withJSONObject: ["thread": ["turns": []]]),
            HTTPURLResponse(url: URL(string: "http://test")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )

        var getRelease: CheckedContinuation<Void, Never>?
        HTTPClient.beforeGet = { await withCheckedContinuation { getRelease = $0 } }
        let revisionTask = Task { @MainActor in
            await SessionRemoteService.open(threadId: thread.id, endpoint: endpoint, store: store, context: context)
        }
        while getRelease == nil { await Task.yield() }
        endpoint.connectionRevision = UUID()
        getRelease?.resume()
        let revisionResult = await revisionTask.value
        let revisionSessionCount = try context.fetchCount(FetchDescriptor<Session>())
        precondition(!revisionResult)
        precondition(revisionSessionCount == 0)
        precondition(HTTPClient.postPaths.isEmpty)

        HTTPClient.beforeGet = nil
        endpoint.connectionRevision = nil
        let removedEndpoint = Endpoint()
        context.insert(removedEndpoint)
        let removedStore = SessionRemoteStore()
        var removedRelease: CheckedContinuation<Void, Never>?
        HTTPClient.beforeGet = { await withCheckedContinuation { removedRelease = $0 } }
        let removedTask = Task { @MainActor in
            await SessionRemoteService.open(
                threadId: thread.id, endpoint: removedEndpoint, store: removedStore, context: context)
        }
        while removedRelease == nil { await Task.yield() }
        context.delete(removedEndpoint)
        removedRelease?.resume()
        let removedResult = await removedTask.value
        let removedSessionCount = try context.fetchCount(FetchDescriptor<Session>())
        precondition(!removedResult)
        precondition(removedSessionCount == 0)
        precondition(HTTPClient.postPaths.isEmpty)

        HTTPClient.beforeGet = nil
        var importRelease: CheckedContinuation<Void, Never>?
        var historyRelease: CheckedContinuation<Void, Never>?
        HTTPClient.beforePost = { path in
            if path.contains("/import") {
                await withCheckedContinuation { importRelease = $0 }
            }
        }
        ChatActions.beforeImport = { await withCheckedContinuation { historyRelease = $0 } }
        let importTask = Task { @MainActor in
            await SessionRemoteService.open(thread, endpoint: endpoint, store: store, context: context)
        }
        while importRelease == nil { await Task.yield() }
        importRelease?.resume()
        importRelease = nil
        while historyRelease == nil { await Task.yield() }
        endpoint.connectionRevision = UUID()
        historyRelease?.resume()
        historyRelease = nil
        let changedDuringImport = await importTask.value
        let changedSessionCount = try context.fetchCount(FetchDescriptor<Session>())
        precondition(!changedDuringImport)
        precondition(changedSessionCount == 0)

        endpoint.connectionRevision = nil
        historyRelease = nil
        let canceledImportTask = Task { @MainActor in
            await SessionRemoteService.open(thread, endpoint: endpoint, store: store, context: context)
        }
        while importRelease == nil { await Task.yield() }
        importRelease?.resume()
        importRelease = nil
        while historyRelease == nil { await Task.yield() }
        canceledImportTask.cancel()
        historyRelease?.resume()
        let canceledResult = await canceledImportTask.value
        let canceledSessionCount = try context.fetchCount(FetchDescriptor<Session>())
        let canceledWindowCount = try context.fetchCount(FetchDescriptor<Window>())
        precondition(!canceledResult)
        precondition(canceledSessionCount == 0)
        precondition(canceledWindowCount == 0)

        HTTPClient.beforePost = nil
        ChatActions.beforeImport = nil
        let existing = Session(endpoint: endpoint, title: "Existing")
        existing.codexThreadId = thread.id
        context.insert(existing)
        HTTPClient.beforeGet = nil
        HTTPClient.getCalls = 0
        HTTPClient.postPaths = []
        let existingResult = await SessionRemoteService.open(
            threadId: thread.id, endpoint: endpoint, store: store, context: context)
        precondition(existingResult)
        precondition(HTTPClient.getCalls == 0 && HTTPClient.postPaths.isEmpty)
        precondition(existing.title == "Existing")

        context.delete(existing)
        HTTPClient.postPaths = []
        ChatActions.importResult = true
        let importResult = await SessionRemoteService.open(thread, endpoint: endpoint, store: store, context: context)
        let importedSessionCount = try context.fetchCount(FetchDescriptor<Session>())
        let importedWindowCount = try context.fetchCount(FetchDescriptor<Window>())
        precondition(importResult)
        precondition(importedSessionCount == 1)
        precondition(importedWindowCount >= 1)
        print("Remote open fencing passed revision, cancellation cleanup, existing reuse and import mutation tests")
    }
}
