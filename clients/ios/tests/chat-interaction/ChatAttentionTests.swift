import Foundation
import SwiftData

enum ChatAttentionTests {
    @MainActor static func run() async {
        let container = try! ModelContainer(
            for: Session.self, Endpoint.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let endpoint = Endpoint()
        endpoint.capabilities = ["codexAttentionBatch"]
        context.insert(endpoint)
        let second = Endpoint()
        second.capabilities = ["codexAttentionBatch"]
        context.insert(second)
        let sessions = (0..<205).map { index in
            let session = Session(endpoint: endpoint, path: "/fixture/\(index)")
            session.provider = .codex
            session.existsOnServer = true
            session.codexThreadId = "thread-\(index)"
            context.insert(session)
            return session
        }
        let other = Session(endpoint: second, path: "/other")
        other.provider = .codex
        other.existsOnServer = true
        other.codexThreadId = "other-thread"
        context.insert(other)
        let archived = Session(endpoint: endpoint, path: "/archived")
        archived.provider = .codex
        archived.existsOnServer = true
        archived.isArchived = true
        context.insert(archived)
        let legacy = Session(endpoint: endpoint, path: "/claude")
        legacy.existsOnServer = true
        context.insert(legacy)
        let store = ChatInteractionStore.shared
        HTTPClient.postResponse = nil
        HTTPClient.postBodies = []
        HTTPClient.postHandler = { _, body in
            let ids = body["sessionIds"] as! [String]
            precondition(ids.count <= 100)
            let updates: [[String: Any]] = ids.map { id in
                let session = (sessions + [other]).first { $0.id.uuidString == id }!
                return [
                    "sessionId": id, "threadId": session.codexThreadId!,
                    "requests": [["requestId": "approval-\(id)", "method": "approval", "params": [:]]],
                    "agentAttention": [["requestId": "child-\(id)", "threadId": "helper-\(id)"]],
                ]
            }
            return (
                try! JSONSerialization.data(withJSONObject: ["sessions": updates]),
                HTTPURLResponse(
                    url: URL(string: "https://fixture.local")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }
        await ChatAttentionService.refresh(context: context)
        precondition(HTTPClient.postBodies.count == 4)
        precondition(sessions.allSatisfy(\.needsAttention) && other.needsAttention)
        precondition(!archived.needsAttention && !legacy.needsAttention)
        for session in sessions.dropFirst() { session.isArchived = true }
        other.isArchived = true
        let session = sessions[0]
        let approval = store.requests[session.id]!.first!
        HTTPClient.postHandler = { _, body in
            (
                try! JSONSerialization.data(withJSONObject: [
                    "sessions": [
                        [
                            "sessionId": session.id.uuidString, "threadId": session.codexThreadId!,
                            "requests": [], "agentAttention": [],
                        ]
                    ]
                ]),
                HTTPURLResponse(
                    url: URL(string: "https://fixture.local")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }
        HTTPClient.beforePost = {
            _ = store.add(
                ChatInteraction(id: "new-approval", method: "approval", paramsJSON: "{}"), sessionId: session.id)
            store.updateAgent(threadId: "new-helper", requestId: "new-child", pending: true, sessionId: session.id)
        }
        await ChatAttentionService.refresh(context: context)
        precondition(store.requests[session.id]?.count == 2 && store.agentRequests[session.id]?.count == 2)
        HTTPClient.beforePost = { endpoint.connectionRevision = UUID() }
        await ChatAttentionService.refresh(context: context)
        precondition(store.requests[session.id]?.contains(approval) == true && session.needsAttention)
        HTTPClient.beforePost = { session.codexThreadId = "new-thread" }
        await ChatAttentionService.refresh(context: context)
        precondition(session.needsAttention)
        HTTPClient.beforePost = nil
        HTTPClient.postHandler = nil
        HTTPClient.postResponse = nil
        await ChatAttentionService.refresh(context: context)
        precondition(session.needsAttention && store.hasAttention(sessionId: session.id))
        HTTPClient.postResponse = (
            Data("{\"sessions\":[]}".utf8),
            HTTPURLResponse(
                url: URL(string: "https://fixture.local")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        await ChatAttentionService.refresh(context: context)
        precondition(session.needsAttention)
        HTTPClient.postResponse = (
            try! JSONSerialization.data(withJSONObject: [
                "sessions": [
                    [
                        "sessionId": session.id.uuidString, "threadId": "wrong-thread", "requests": [],
                        "agentAttention": [],
                    ]
                ]
            ]),
            HTTPURLResponse(
                url: URL(string: "https://fixture.local")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        await ChatAttentionService.refresh(context: context)
        precondition(session.needsAttention)
        HTTPClient.postResponse = (
            try! JSONSerialization.data(withJSONObject: [
                "sessions": [
                    [
                        "sessionId": session.id.uuidString, "threadId": session.codexThreadId!, "requests": [],
                        "agentAttention": [],
                    ]
                ]
            ]),
            HTTPURLResponse(
                url: URL(string: "https://fixture.local")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        for malformed: [String: Any] in [
            ["requests": [[:]], "agentAttention": []],
            ["requests": [], "agentAttention": [[:]]],
            [
                "requests": [
                    ["requestId": "same", "method": "approval"], ["requestId": "same", "method": "approval"],
                ], "agentAttention": [],
            ],
            [
                "requests": [],
                "agentAttention": [
                    ["threadId": "one", "requestId": "same"], ["threadId": "two", "requestId": "same"],
                ],
            ],
            [
                "requests": [["requestId": "bad-params", "method": "approval", "params": [1, 2]]], "agentAttention": [],
            ],
        ] {
            ChatInteractionService.apply(
                malformed, session: session,
                revision: store.revisions[session.id, default: 0],
                agentRevision: store.agentRevisions[session.id, default: 0])
            precondition(
                session.needsAttention && store.requests[session.id]?.count == 2
                    && store.agentRequests[session.id]?.count == 2)
        }
        let before = HTTPClient.postCount
        HTTPClient.beforePost = { try? await Task.sleep(for: .seconds(30)) }
        let polling = Task { await ChatAttentionService.observe(context: context, interval: .milliseconds(1)) }
        while HTTPClient.postCount == before { await Task.yield() }
        polling.cancel()
        await polling.value
        precondition(session.needsAttention && HTTPClient.postCount == before + 1)
        HTTPClient.beforePost = nil
        await ChatAttentionService.refresh(context: context)
        precondition(!session.needsAttention && !store.hasAttention(sessionId: session.id))
        HTTPClient.postHandler = nil
        HTTPClient.postResponse = nil
        HTTPClient.postBodies = []
        print(
            "PASS inactive attention host batching, archived/provider filters, live revision and connection/thread fences, offline retention, malformed snapshots and foreground cancellation"
        )
    }
}
