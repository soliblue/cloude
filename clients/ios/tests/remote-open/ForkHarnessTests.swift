import Foundation
import SwiftData

struct ForkHarnessTests {
    @MainActor static func run() async throws {
        for scenario in [
            "snapshot", "running", "unsupported", "missing", "mismatch", "active", "revision", "canceled",
            "import-failed", "import-revision", "removed", "superseded", "import-superseded",
        ] {
            let container = try ModelContainer(
                for: Endpoint.self, Session.self, Window.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let context = container.mainContext
            let endpoint = Endpoint()
            endpoint.capabilities = scenario == "unsupported" ? [] : ["codexActiveFork"]
            context.insert(endpoint)
            let source = Session(endpoint: endpoint, path: "/repo", title: "Parent")
            source.codexThreadId = "parent-thread"
            source.isStreaming = scenario == "running" || scenario == "unsupported"
            context.insert(source)
            try context.save()
            var history: [String: Any] = [
                "id": "fork-thread", "cwd": "/canonical/repo", "createdAt": 1,
                "status": ["type": "idle"],
                "turns": [
                    [
                        "id": "finished-turn", "status": "completed",
                        "items": [["id": "plan", "type": "plan", "text": "Host-authoritative plan"]],
                    ]
                ],
            ]
            if scenario == "missing" { history.removeValue(forKey: "turns") }
            if scenario == "mismatch" { history["id"] = "other-thread" }
            if scenario == "active" { history["turns"] = [["status": "inProgress", "items": []]] }
            HTTPClient.postResponse = (
                try JSONSerialization.data(withJSONObject: ["threadId": "fork-thread", "thread": history]),
                HTTPURLResponse(
                    url: URL(string: "http://fixture")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
            HTTPClient.postPaths = []
            HTTPClient.beforePost = nil
            ChatActions.beforeImport = nil
            ChatActions.importResult = scenario != "import-failed"
            ChatActions.importedHistory = nil
            ChatActions.discarded = []
            SessionActions.copiedHistory = true
            if scenario == "revision" { HTTPClient.beforePost = { _ in endpoint.connectionRevision = UUID() } }
            if scenario == "removed" { HTTPClient.beforePost = { _ in context.delete(source) } }
            if scenario == "import-revision" { ChatActions.beforeImport = { endpoint.connectionRevision = UUID() } }
            if scenario == "superseded" {
                HTTPClient.beforePost = { _ in
                    SessionActions.restoreFork(source, id: UUID(), scope: source.forkScopeKey)
                }
            }
            if scenario == "import-superseded" {
                ChatActions.beforeImport = {
                    SessionActions.restoreFork(source, id: UUID(), scope: source.forkScopeKey)
                }
            }
            let result: Bool
            if scenario == "canceled" {
                var release: CheckedContinuation<Void, Never>?
                HTTPClient.beforePost = { _ in await withCheckedContinuation { release = $0 } }
                let task = Task { @MainActor in
                    await SessionForkService.fork(session: source, context: context, store: SessionForkStore())
                }
                while release == nil { await Task.yield() }
                task.cancel()
                release?.resume()
                result = await task.value
            } else {
                result = await SessionForkService.fork(session: source, context: context, store: SessionForkStore())
            }
            let succeeds = scenario == "snapshot" || scenario == "running"
            precondition(result == succeeds, scenario)
            let windows = try context.fetch(FetchDescriptor<Window>())
            let sessions = try context.fetch(FetchDescriptor<Session>())
            if succeeds {
                precondition(!SessionActions.copiedHistory, "Must not copy phone-only transcript")
                precondition(windows.count == 1 && sessions.count == 2)
                precondition(windows[0].session?.codexThreadId == "fork-thread")
                precondition(windows[0].session?.path == "/canonical/repo")
                precondition(
                    (ChatActions.importedHistory?["turns"] as? [[String: Any]])?.first?["id"] as? String
                        == "finished-turn")
                precondition(source.isStreaming == (scenario == "running"), "Parent remains untouched")
                precondition(source.pendingForkId == nil && windows[0].session?.followsRemote == true)
            } else {
                precondition(windows.isEmpty, scenario)
                precondition(sessions.allSatisfy { $0.id == source.id }, scenario)
                if scenario == "unsupported" { precondition(HTTPClient.postPaths.isEmpty) }
                if scenario == "import-failed" || scenario == "import-revision" {
                    precondition(ChatActions.discarded.isEmpty)
                }
            }
        }
        HTTPClient.beforePost = nil
        ChatActions.beforeImport = nil
        ChatActions.importResult = true
        print(
            "PASS side chats use authoritative history, preserve active parent, reject malformed forks and fence cancellation, endpoint changes and deletion"
        )
    }
}
