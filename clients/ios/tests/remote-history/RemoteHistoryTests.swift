import Foundation
import SwiftData

@main struct RemoteHistoryTests {
    @MainActor static func main() async throws {
        let container = try ModelContainer(
            for: Session.self, Endpoint.self, ChatMessage.self, ChatToolCall.self, ChatGitChange.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let endpoint = Endpoint()
        context.insert(endpoint)
        let session = Session(endpoint: endpoint)
        context.insert(session)
        var history: [String: Any] = [
            "createdAt": 1000.0,
            "turns": [
                [
                    "status": "inProgress",
                    "items": [
                        ["id": "user-1", "type": "userMessage", "content": [["type": "text", "text": "hello"]]],
                        ["id": "assistant-1", "type": "agentMessage", "text": "Working"],
                        [
                            "id": "tool-1", "type": "commandExecution", "command": "pwd", "aggregatedOutput": "",
                            "status": "inProgress",
                        ],
                    ],
                ]
            ],
        ]
        await ChatActions.importHistory(history, session: session, context: context)
        await ChatActions.importHistory(history, session: session, context: context)
        precondition(try! context.fetchCount(FetchDescriptor<ChatMessage>()) == 3)
        precondition(try! context.fetchCount(FetchDescriptor<ChatToolCall>()) == 1)
        precondition(session.remoteIsRunning)
        history["turns"] = [
            [
                "status": "completed",
                "items": [
                    ["id": "user-1", "type": "userMessage", "content": [["type": "text", "text": "hello"]]],
                    ["id": "assistant-1", "type": "agentMessage", "text": "Finished"],
                    [
                        "id": "tool-1", "type": "commandExecution", "command": "pwd",
                        "aggregatedOutput": "/tmp/project", "status": "completed",
                    ],
                    ["id": "assistant-2", "type": "agentMessage", "text": "All done"],
                ],
            ]
        ]
        await ChatActions.importHistory(history, session: session, context: context)
        precondition(try! context.fetchCount(FetchDescriptor<ChatMessage>()) == 4)
        precondition(
            try! context.fetch(FetchDescriptor<ChatMessage>()).first(where: { $0.remoteItemId == "assistant-1" })?.text
                == "Finished")
        precondition(try! context.fetch(FetchDescriptor<ChatToolCall>()).first?.result == "/tmp/project")
        precondition(!session.remoteIsRunning)
        HTTPClient.response = nil
        await SessionRemoteFollowService.refresh(session: session, context: context)
        precondition(try! context.fetchCount(FetchDescriptor<ChatMessage>()) == 4)
        precondition(HTTPClient.calls == 1)
        session.isStreaming = true
        HTTPClient.response = (
            try JSONSerialization.data(withJSONObject: ["thread": history]),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        await SessionRemoteFollowService.refresh(session: session, context: context)
        precondition(HTTPClient.calls == 1)
        session.isStreaming = false
        session.followsRemote = false
        await SessionRemoteFollowService.refresh(session: session, context: context)
        precondition(HTTPClient.calls == 1)
        let queued = ChatActions.addUserMessage(
            sessionId: session.id, text: "/review", images: [], state: .queued,
            references: [ChatReference(name: "review", path: "/skills/review/SKILL.md", kind: "skill")],
            context: context)
        let queueQuery = FetchDescriptor<ChatMessage>(predicate: #Predicate<ChatMessage> { $0.stateRaw == "queued" })
        let timelineQuery = FetchDescriptor<ChatMessage>(predicate: #Predicate<ChatMessage> { $0.stateRaw != "queued" })
        precondition(try! context.fetchCount(queueQuery) == 1)
        precondition(try! context.fetchCount(timelineQuery) == 4)
        queued.state = .complete
        precondition(try! context.fetchCount(queueQuery) == 0)
        precondition(try! context.fetchCount(timelineQuery) == 5)
        _ = ChatActions.beginAssistant(sessionId: session.id, context: context)
        let forkId = UUID()
        ChatActions.copyHistory(from: session.id, to: forkId, context: context)
        let forkQuery = FetchDescriptor<ChatMessage>(predicate: #Predicate<ChatMessage> { $0.sessionId == forkId })
        let forked = try context.fetch(forkQuery)
        precondition(forked.count == 5 && forked.allSatisfy { $0.state == .complete })
        precondition(forked.first(where: { $0.text == "/review" })?.references.first?.path == "/skills/review/SKILL.md")
        print("Passed queue-to-timeline movement and complete-only fork with native skill references")
        let followed = Session(endpoint: endpoint)
        context.insert(followed)
        HTTPClient.response = (
            try JSONSerialization.data(withJSONObject: ["thread": history]),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200, httpVersion: nil,
                headerFields: ["ETag": "snapshot-1"])!
        )
        await SessionRemoteFollowService.refresh(session: followed, context: context)
        precondition(followed.remoteHistoryETag == "snapshot-1")
        HTTPClient.response = (
            Data(),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 304, httpVersion: nil,
                headerFields: ["ETag": "snapshot-1"])!
        )
        await SessionRemoteFollowService.refresh(session: followed, context: context)
        precondition(HTTPClient.lastHeaders["If-None-Match"] == "snapshot-1")
        precondition(followed.remoteHistoryETag == "snapshot-1")
        let followedId = followed.id
        let followedQuery = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> { $0.sessionId == followedId })
        precondition(try! context.fetchCount(followedQuery) == 4)
        let detached = Session(endpoint: endpoint)
        context.insert(detached)
        var releaseResponse: CheckedContinuation<Void, Never>?
        HTTPClient.beforeGetResponse = { await withCheckedContinuation { releaseResponse = $0 } }
        HTTPClient.response = (
            try JSONSerialization.data(withJSONObject: ["thread": history]),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200, httpVersion: nil,
                headerFields: ["ETag": "detached"])!
        )
        let pendingFetch = Task { @MainActor in
            await SessionRemoteFollowService.refresh(session: detached, context: context)
        }
        while releaseResponse == nil { await Task.yield() }
        SessionRemoteFollowService.detach(sessionId: detached.id)
        releaseResponse?.resume()
        await pendingFetch.value
        HTTPClient.beforeGetResponse = nil
        let detachedId = detached.id
        let detachedQuery = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> { $0.sessionId == detachedId })
        precondition(try! context.fetchCount(detachedQuery) == 0)
        precondition(detached.remoteHistoryETag == nil)
        print("Passed detach while history response is in flight")
        let interrupted = Session(endpoint: endpoint)
        context.insert(interrupted)
        let interruptedId = interrupted.id
        let interruptedQuery = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> { $0.sessionId == interruptedId })
        let largeHistory: [String: Any] = [
            "createdAt": 1000.0,
            "turns": [
                [
                    "status": "completed",
                    "items": (0..<10000).map {
                        ["id": "large-\($0)", "type": "agentMessage", "text": "imported \($0)"]
                    },
                ]
            ],
        ]
        let importTask = Task { @MainActor in
            await ChatActions.importHistory(
                largeHistory, session: interrupted, context: context, requiringRemoteFollow: true)
        }
        while (try! context.fetchCount(interruptedQuery)) == 0 { await Task.yield() }
        interrupted.isStreaming = true
        let completed = await importTask.value
        precondition(!completed)
        precondition(try! context.fetchCount(interruptedQuery) < 10000)
        print("Passed conditional ETag polling and mid-import local-turn interruption")
        let nativeEdit = ChatToolCall(
            id: "native-edit", messageId: UUID(), sessionId: session.id, name: "Edit", inputSummary: "two files",
            inputJSON: """
                {"changes":[{"path":"a.swift","diff":"@@ -1 +1 @@\\n-old\\n+new","kind":{"type":"update","move_path":"b.swift"}},{"path":"gone.swift","diff":"-gone","kind":{"type":"delete"}}]}
                """)
        precondition(nativeEdit.fileChanges.count == 2 && nativeEdit.shortLabel == "2 files")
        precondition(nativeEdit.fileChanges[0].movedPath == "b.swift" && nativeEdit.fileChanges[0].title == "Renamed")
        nativeEdit.result = """
            [{"path":"final.swift","diff":"+new","kind":{"type":"add"}}]
            """
        precondition(nativeEdit.fileChanges.count == 1 && nativeEdit.shortLabel == "final.swift")
        nativeEdit.result = """
            [{"path":"changed.swift","diff":"+changed","kind":{"type":"add"}}]
            """
        precondition(nativeEdit.fileChanges.first?.path == "changed.swift")
        let nativeAgent = ChatToolCall(
            id: "native-agent", messageId: UUID(), sessionId: session.id, name: "Agent", inputSummary: "agent",
            inputJSON: """
                {"receiverThreadIds":["agent-1","agent-2"],"agentsStates":{"agent-1":{"status":"errored","message":"Failed"}}}
                """)
        precondition(nativeAgent.agentActivities.count == 2)
        precondition(nativeAgent.agentActivities[0].symbol == "exclamationmark.circle")
        precondition(nativeAgent.agentActivities[1].status == "unknown")
        let liveSpawn = ChatToolCall(
            id: "exec-call", messageId: UUID(), sessionId: session.id, name: "Agent",
            inputSummary: "exec-random-dictionary-value",
            inputJSON: """
                {"type":"collabAgentToolCall","id":"exec-call","tool":"spawnAgent","status":"inProgress","senderThreadId":"parent","receiverThreadIds":[],"prompt":"List the top-level filenames without editing files.","model":"gpt-5.6-luna","agentsStates":{}}
                """)
        precondition(liveSpawn.shortLabel == "Start agent" && liveSpawn.agentActivities.isEmpty)
        precondition(ChatToolCall.summarize(name: "Agent", input: liveSpawn.parsedInput) == "Start agent")
        liveSpawn.result = """
            {"type":"collabAgentToolCall","id":"exec-call","tool":"spawnAgent","status":"completed","receiverThreadIds":["real-child-thread"],"agentsStates":{"real-child-thread":{"status":"pendingInit","message":null}}}
            """
        precondition(
            liveSpawn.agentActivities.first?.id == "real-child-thread"
                && liveSpawn.agentActivities.first?.title == "Starting")
        precondition(liveSpawn.agentActivities.first?.isRunning == true && liveSpawn.shortLabel == "Start agent")
        liveSpawn.result = """
            {"receiverThreadIds":["real-child-thread"],"agentsStates":{"real-child-thread":{"status":"completed","message":"README.md"}}}
            """
        precondition(
            liveSpawn.agentActivities.first?.title == "Completed"
                && liveSpawn.agentActivities.first?.text == "README.md")
        precondition(ChatAgentActivity.label(["tool": "wait", "id": "exec-other"]) == "Wait for agents")
        let modernAgent = ChatToolCall(
            id: "activity-event", messageId: UUID(), sessionId: session.id, name: "subAgentActivity",
            inputSummary: "irrelevant-id",
            inputJSON: """
                {"type":"subAgentActivity","id":"activity-event","agentThreadId":"modern-child","agentPath":"/root/file_inventory","kind":"started"}
                """)
        precondition(modernAgent.kind == .task && modernAgent.shortLabel == "file_inventory")
        precondition(
            modernAgent.agentActivities.first?.id == "modern-child"
                && modernAgent.agentActivities.first?.name == "file_inventory")
        precondition(
            modernAgent.agentActivities.first?.title == "Started"
                && modernAgent.agentActivities.first?.isRunning == false)
        modernAgent.result = """
            {"agentThreadId":"modern-child","agentPath":"/root/file_inventory","kind":"completed"}
            """
        precondition(modernAgent.agentActivities.first?.title == "Completed")
        precondition(
            ChatAgentActivity.label(["description": "Inspect authentication", "subagent_type": "explorer"])
                == "Inspect authentication")
        precondition(
            ChatAgentActivity.collect(input: ["id": "exec-no-child", "tool": "spawnAgent"], result: [:]).isEmpty)
        print(
            "Passed native file changes and both agent schemas: deterministic labels, real child IDs, lifecycle states and updated result caches"
        )
        let reviewSession = Session(endpoint: endpoint)
        context.insert(reviewSession)
        let reviewHistory: [String: Any] = [
            "createdAt": 2000.0,
            "turns": [
                [
                    "status": "completed",
                    "items": [
                        ["id": "entered", "type": "enteredReviewMode", "review": "uncommitted changes"],
                        ["id": "review-result", "type": "exitedReviewMode", "review": "Found one retry bug."],
                    ],
                ]
            ],
        ]
        await ChatActions.importHistory(reviewHistory, session: reviewSession, context: context)
        await ChatActions.importHistory(reviewHistory, session: reviewSession, context: context)
        let reviewSessionId = reviewSession.id
        let reviewMessages = try context.fetch(
            FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == reviewSessionId }))
        precondition(reviewMessages.count == 2 && reviewMessages.contains(where: { $0.text == "Found one retry bug." }))
        precondition(
            try! context.fetchCount(
                FetchDescriptor<ChatToolCall>(predicate: #Predicate { $0.sessionId == reviewSessionId })) == 0)
        let deduplicatedReview = Session(endpoint: endpoint)
        context.insert(deduplicatedReview)
        await ChatActions.importHistory(
            [
                "turns": [
                    [
                        "items": [
                            ["id": "report", "type": "agentMessage", "text": "No findings."],
                            ["id": "exit", "type": "exitedReviewMode", "review": "No findings."],
                        ]
                    ]
                ]
            ], session: deduplicatedReview, context: context)
        let deduplicatedReviewId = deduplicatedReview.id
        precondition(
            try! context.fetchCount(
                FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == deduplicatedReviewId })) == 1)
        let incrementalReview = Session(endpoint: endpoint)
        context.insert(incrementalReview)
        let exitItem = ["id": "exit-first", "type": "exitedReviewMode", "review": "  No findings.\n"]
        await ChatActions.importHistory(
            ["turns": [["items": [exitItem]]]], session: incrementalReview, context: context)
        await ChatActions.importHistory(
            [
                "turns": [
                    ["items": [exitItem, ["id": "later-report", "type": "agentMessage", "text": "No findings."]]]
                ]
            ],
            session: incrementalReview, context: context)
        let incrementalId = incrementalReview.id
        precondition(
            try! context.fetchCount(
                FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == incrementalId })) == 1)
        await ChatActions.importHistory(
            [
                "turns": [
                    [
                        "items": [
                            [
                                "id": "shell-output", "type": "commandExecution", "source": "userShell",
                                "command": "pwd", "aggregatedOutput": "/repo", "exitCode": 0,
                            ]
                        ]
                    ]
                ]
            ], session: incrementalReview, context: context)
        precondition(
            try! context.fetch(FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == incrementalId }))
                .first(where: { $0.remoteItemId == "shell-output" })?.model == nil)
        let shellMessage = ChatActions.addUserMessage(
            sessionId: reviewSession.id, text: "Run command", images: [], state: .queued,
            shellCommand: " printf 'hello' | cat\n", context: context)
        precondition(shellMessage.shellCommand == " printf 'hello' | cat\n" && shellMessage.state == .queued)
        shellMessage.state = .complete
        let reviewTarget = ChatReviewTarget(type: .commit, sha: "abcdef12")
        let requestedReview = ChatActions.addUserMessage(
            sessionId: reviewSession.id, text: reviewTarget.prompt, images: [], reviewTarget: reviewTarget,
            context: context)
        let reviewForkId = UUID()
        ChatActions.copyHistory(from: reviewSession.id, to: reviewForkId, context: context)
        let forkedReview = try context.fetch(
            FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == reviewForkId }))
        precondition(
            forkedReview.contains(where: { $0.shellCommand == shellMessage.shellCommand })
                && requestedReview.reviewTarget == reviewTarget
                && forkedReview.contains(where: { $0.reviewTarget == reviewTarget }))
        print(
            "Passed readable imported review lifecycle, final report deduplication and persisted review target copying")
        let runtimeSession = Session(endpoint: endpoint)
        context.insert(runtimeSession)
        let unfinished: [[String: Any]] = [["status": "inProgress", "items": []]]
        for status in ["notLoaded", "idle", "systemError", "unknownFutureStatus"] {
            await ChatActions.importHistory(
                ["status": ["type": status], "turns": unfinished], session: runtimeSession, context: context)
            precondition(!runtimeSession.remoteIsRunning)
        }
        await ChatActions.importHistory(
            ["status": ["type": "active", "activeFlags": ["waitingOnApproval"]], "turns": []],
            session: runtimeSession, context: context)
        precondition(runtimeSession.remoteIsRunning)
        await ChatActions.importHistory(
            ["status": ["type": "idle"], "turns": [["status": "interrupted", "items": []]]],
            session: runtimeSession, context: context)
        precondition(!runtimeSession.remoteIsRunning && runtimeSession.remoteTurnStatus == "interrupted")
        var child: [String: Any] = [
            "id": "child", "cwd": "/repo", "preview": "", "updatedAt": 1,
            "agentNickname": "Descartes",
            "source": [
                "subAgent": [
                    "thread_spawn": [
                        "agent_path": "/root/afto_helper", "agent_nickname": "Descartes", "depth": 1,
                    ]
                ]
            ],
            "status": ["type": "notLoaded"], "turns": unfinished,
        ]
        precondition(
            try! JSONDecoder().decode(
                SessionRemoteThread.self,
                from: JSONSerialization.data(withJSONObject: child)
            ).title == "Descartes")
        child["agentNickname"] = NSNull()
        child["source"] = ["subAgent": ["thread_spawn": ["agent_path": "/root/afto_helper", "depth": 1]]]
        precondition(
            try! JSONDecoder().decode(
                SessionRemoteThread.self,
                from: JSONSerialization.data(withJSONObject: child)
            ).title == "afto_helper")
        child["name"] = " Named task "
        precondition(
            try! JSONDecoder().decode(
                SessionRemoteThread.self,
                from: JSONSerialization.data(withJSONObject: child)
            ).title == "Named task")
        child["name"] = " "
        child["source"] = "cli"
        child["preview"] = "Prompt preview"
        precondition(
            try! JSONDecoder().decode(
                SessionRemoteThread.self,
                from: JSONSerialization.data(withJSONObject: child)
            ).title == "Prompt preview")
        child["preview"] = ""
        child["agentNickname"] = "Descartes"
        HTTPClient.response = (
            try JSONSerialization.data(withJSONObject: ["thread": child]),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200,
                httpVersion: nil, headerFields: ["ETag": "runtime-snapshot"])!
        )
        for old in try context.fetch(FetchDescriptor<Session>()) { old.remoteIsRunning = false }
        runtimeSession.remoteIsRunning = true
        runtimeSession.hasCustomTitle = false
        let refreshCalls = HTTPClient.calls
        await SessionRemoteFollowService.refreshRunning(context: context)
        precondition(HTTPClient.calls == refreshCalls + 1)
        precondition(!runtimeSession.remoteIsRunning && runtimeSession.title == "Descartes")
        await SessionRemoteFollowService.refreshRunning(context: context)
        precondition(HTTPClient.calls == refreshCalls + 1)
        runtimeSession.remoteIsRunning = true
        HTTPClient.response = nil
        await SessionRemoteFollowService.refreshRunning(context: context)
        precondition(runtimeSession.remoteIsRunning)
        HTTPClient.response = (
            try JSONSerialization.data(withJSONObject: ["thread": child]),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200,
                httpVersion: nil, headerFields: nil)!
        )
        HTTPClient.beforeGetResponse = { endpoint.connectionRevision = UUID() }
        await SessionRemoteFollowService.refresh(session: runtimeSession, context: context)
        precondition(runtimeSession.remoteIsRunning)
        HTTPClient.beforeGetResponse = nil
        runtimeSession.hasCustomTitle = true
        runtimeSession.title = "My chosen name"
        await SessionRemoteFollowService.refresh(session: runtimeSession, context: context)
        precondition(!runtimeSession.remoteIsRunning && runtimeSession.title == "My chosen name")
        var releaseDedupResponse: CheckedContinuation<Void, Never>?
        HTTPClient.beforeGetResponse = {
            await withCheckedContinuation { releaseDedupResponse = $0 }
        }
        let dedupCalls = HTTPClient.calls
        let firstRefresh = Task { await SessionRemoteFollowService.refresh(session: runtimeSession, context: context) }
        while releaseDedupResponse == nil { await Task.yield() }
        var secondStarted = false
        let secondRefresh = Task {
            secondStarted = true
            await SessionRemoteFollowService.refresh(session: runtimeSession, context: context)
        }
        while !secondStarted { await Task.yield() }
        precondition(HTTPClient.calls == dedupCalls + 1)
        releaseDedupResponse?.resume()
        await firstRefresh.value
        await secondRefresh.value
        HTTPClient.beforeGetResponse = nil
        precondition(HTTPClient.calls == dedupCalls + 1)
        print(
            "Passed runtime status authority, interrupted state, real agent metadata titles, bounded refresh, offline retention and changed endpoint fencing"
        )
        print(
            "Passed remote history deduplication, content updates, running status, offline preservation, active-turn isolation, and follow opt-out"
        )
        let planSession = Session(endpoint: endpoint)
        context.insert(planSession)
        let completedPlan = ChatMessage(sessionId: planSession.id, role: .assistant, text: "Selected plan")
        completedPlan.planIsComplete = true
        completedPlan.planEventSeq = 987
        completedPlan.remoteItemId = "native-plan-id"
        context.insert(completedPlan)
        let incompletePlan = ChatMessage(sessionId: planSession.id, role: .assistant, text: "Still writing")
        incompletePlan.planIsComplete = false
        context.insert(incompletePlan)
        let planFork = UUID()
        ChatActions.copyHistory(from: planSession.id, to: planFork, context: context)
        let copiedPlans = try context.fetch(
            FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == planFork }))
        precondition(
            copiedPlans.count == 1 && copiedPlans[0].planIsComplete == true && copiedPlans[0].text == "Selected plan")
        precondition(copiedPlans[0].planEventSeq == nil && copiedPlans[0].remoteItemId == nil)
        print(
            "PASS fork preserves completed plan identity, excludes incomplete plan and clears transport sequence/native IDs"
        )
        try await ChatImageHistoryTests.run(context: context, endpoint: endpoint)
    }
}
