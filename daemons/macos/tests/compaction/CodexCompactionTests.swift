import Foundation

@main struct CodexCompactionTests {
    static func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<200 where !condition() { try await Task.sleep(for: .milliseconds(10)) }
        precondition(condition(), "Timed out waiting for compaction state")
    }

    static func main() async throws {
        let fixture = CodexCompactionFixture()
        let service = fixture.makeService()
        precondition(service.start(threadId: "task").0 == 202)
        precondition(service.start(threadId: "task").0 == 202)
        try await wait { fixture.count("thread/compact/start") == 1 }
        precondition(fixture.count("thread/read") == 1)
        service.notification(["method": "turn/started", "params": ["threadId": "task", "turn": ["id": "compaction"]]])
        service.notification([
            "method": "thread/tokenUsage/updated",
            "params": [
                "threadId": "task", "turnId": "compaction",
                "tokenUsage": ["last": ["totalTokens": 123], "modelContextWindow": 200000],
            ],
        ])
        service.notification([
            "method": "turn/completed",
            "params": ["threadId": "other", "turn": ["id": "compaction", "status": "completed"]],
        ])
        precondition(service.snapshot(threadId: "task")["status"] as? String == "pending")
        service.notification([
            "method": "error", "params": ["threadId": "task", "turnId": "compaction", "willRetry": true],
        ])
        precondition(service.snapshot(threadId: "task")["status"] as? String == "pending")
        service.notification([
            "method": "turn/completed",
            "params": ["threadId": "task", "turn": ["id": "compaction", "status": "completed"]],
        ])
        precondition(service.snapshot(threadId: "task")["status"] as? String == "completed")
        precondition(service.snapshot(threadId: "task")["contextTokens"] as? Int == 123)
        precondition(service.snapshot(threadId: "task")["contextWindow"] as? Int == 200000)
        precondition(fixture.lock.withLock { fixture.released == ["task"] && fixture.reserved.isEmpty })
        service.notification([
            "method": "thread/tokenUsage/updated",
            "params": ["threadId": "task", "turnId": "next-turn", "tokenUsage": ["last": ["totalTokens": 999]]],
        ])
        precondition(service.snapshot(threadId: "task")["contextTokens"] as? Int == 123)
        for mode in ["apikey", "quota", "active", "provider", "custom"] {
            let blocked = CodexCompactionFixture()
            blocked.accountType = mode == "apikey" ? "apiKey" : "chatgpt"
            blocked.usedPercent = mode == "quota" ? 100 : 0
            blocked.active = mode == "active"
            blocked.provider = mode == "provider" ? "other" : "openai"
            blocked.customProvider = mode == "custom"
            let blockedService = blocked.makeService()
            precondition(blockedService.start(threadId: mode).0 == 202)
            try await wait { blockedService.snapshot(threadId: mode)["status"] as? String == "failed" }
            precondition(blocked.count("thread/compact/start") == 0)
            precondition(blocked.lock.withLock { blocked.released == [mode] })
        }
        let interrupted = CodexCompactionFixture()
        interrupted.holdRead = true
        let interruptedService = interrupted.makeService()
        _ = interruptedService.start(threadId: "interrupted")
        try await wait { interrupted.count("thread/read") == 1 }
        interruptedService.disconnected()
        precondition(interruptedService.snapshot(threadId: "interrupted")["status"] as? String == "failed")
        let held = interrupted.lock.withLock { interrupted.held }
        for callback in held {
            callback(.success(["thread": ["cwd": "/fixture", "modelProvider": "openai", "status": ["type": "idle"]]]))
        }
        try await Task.sleep(for: .milliseconds(50))
        precondition(interrupted.count("thread/compact/start") == 0)
        precondition(interrupted.lock.withLock { interrupted.released == ["interrupted"] })
        let conflict = CodexCompactionService(
            transport: fixture.send, reserve: { _ in false },
            release: { _ in preconditionFailure("Unreserved release") }, observing: false)
        precondition(conflict.start(threadId: "busy").0 == 409)
        print(
            "Native compaction: duplicate starts, subscription/provider/quota guards, task reservation, lifecycle, fresh usage, unrelated events and disconnect fencing passed"
        )
    }
}
