import Foundation

@main struct ScheduleTests {
    @MainActor static func main() async throws {
        let cacheRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = ScheduleCache(root: cacheRoot)
        defer { try? FileManager.default.removeItem(at: cacheRoot) }
        let endpoint = Endpoint()
        endpoint.capabilities = ["agentSchedules"]
        let session = Session(endpoint: endpoint, path: "/fixture")
        session.provider = .codex
        session.modelRaw = "gpt-5.6-luna"
        var draft = ScheduleDraft(session: session)
        draft.name = "Daily review"
        draft.prompt = "Review changes without editing files."
        draft.timeZone = "Europe/Berlin"
        precondition(!draft.enabled && draft.permissionMode == "default" && draft.validationError == nil)
        precondition((draft.body["schedule"] as? [String: Any])?["daysOfWeek"] as? [Int] == Array(1...7))
        precondition((draft.body["task"] as? [String: Any])?["model"] as? String == "gpt-5.6-luna")
        draft.kind = "interval"
        draft.minutes = 14
        let editor = ScheduleStore()
        let invalid = await ScheduleService.save(draft, session: session, store: editor)
        precondition(!invalid && HTTPClient.requests.isEmpty)
        draft.minutes = 60
        HTTPClient.postResponse = nil
        let uncertain = await ScheduleService.save(draft, session: session, store: editor)
        precondition(!uncertain && editor.uncertainSave && !editor.isMutating)
        let requestId = HTTPClient.requests.last!.2["requestId"] as! String
        HTTPClient.postResponse = HTTPClient.response([:], status: 201)
        let retried = await ScheduleService.save(draft, session: session, store: editor)
        precondition(
            retried && !editor.uncertainSave && HTTPClient.requests.last!.2["requestId"] as? String == requestId)
        let job: [String: Any] = [
            "id": UUID().uuidString, "name": draft.name, "enabled": false, "originSessionId": session.id.uuidString,
            "task": draft.body["task"]!, "schedule": draft.body["schedule"]!, "revision": 4,
            "createdAt": 1_000, "updatedAt": 2_000, "nextRunAt": NSNull(),
        ]
        let schedule = try JSONDecoder().decode(Schedule.self, from: JSONSerialization.data(withJSONObject: job))
        let editing = ScheduleDraft(session: session, existing: schedule)
        precondition(editing.body["requestId"] == nil && editing.body["revision"] as? Int == 4)
        let store = ScheduleStore()
        HTTPClient.getResponse = HTTPClient.response(["schedules": [job], "available": true])
        await ScheduleService.load(endpoint: endpoint, store: store, cache: cache)
        precondition(store.schedules.count == 1 && store.schedules[0].revision == 4)
        HTTPClient.getResponse = nil
        await ScheduleService.load(endpoint: endpoint, store: store, cache: cache)
        precondition(store.schedules.count == 1 && store.error != nil && !store.isLoading)
        HTTPClient.getResponse = HTTPClient.response(["schedules": [], "available": true])
        HTTPClient.beforeGet = {
            HTTPClient.postResponse = HTTPClient.response([:])
            _ = await ScheduleService.setEnabled(schedule, enabled: true, endpoint: endpoint, store: store)
        }
        await ScheduleService.load(endpoint: endpoint, store: store, cache: cache)
        precondition(store.schedules.count == 1 && !store.isLoading)
        HTTPClient.beforeGet = nil
        HTTPClient.postResponse = nil
        _ = await ScheduleService.run(schedule, endpoint: endpoint, store: store)
        let runRequestId = HTTPClient.requests.last!.2["requestId"] as! String
        HTTPClient.postResponse = HTTPClient.response([:], status: 202)
        let confirmed = await ScheduleService.run(schedule, endpoint: endpoint, store: store)
        precondition(confirmed && HTTPClient.requests.last!.2["requestId"] as? String == runRequestId)
        precondition(store.runRequestIds[schedule.id] == nil)
        let history = ScheduleStore()
        let first = run(schedule, status: "running", timestamp: 3000)
        let older = run(schedule, status: "completed", timestamp: 1000)
        HTTPClient.getResponse = HTTPClient.response(["runs": [first], "nextCursor": first["runId"]!])
        await ScheduleService.loadRuns(schedule, endpoint: endpoint, store: history, cache: cache)
        HTTPClient.getResponse = HTTPClient.response(["runs": [older]])
        await ScheduleService.loadRuns(schedule, endpoint: endpoint, store: history, more: true, cache: cache)
        let newest = run(schedule, status: "starting", timestamp: 4000)
        HTTPClient.getResponse = HTTPClient.response([
            "runs": [newest, first.merging(["status": "completed"]) { _, new in new }], "nextCursor": first["runId"]!,
        ])
        await ScheduleService.loadRuns(schedule, endpoint: endpoint, store: history, cache: cache)
        precondition(
            history.runs.count == 3 && history.runs[0].status == "starting" && history.runs[1].status == "completed")
        precondition(history.nextCursor == nil && history.runs[2].date.timeIntervalSince1970 == 1)
        HTTPClient.beforeGet = { endpoint.connectionRevision = UUID() }
        await ScheduleService.load(endpoint: endpoint, store: store, cache: cache)
        HTTPClient.beforeGet = nil
        let count = HTTPClient.requests.count
        let staleSave = await ScheduleService.save(draft, session: session, store: editor)
        let staleRun = await ScheduleService.run(schedule, endpoint: endpoint, store: store)
        precondition(!staleSave && !staleRun && HTTPClient.requests.count == count)
        let fresh = ScheduleDraft(session: session, existing: schedule)
        HTTPClient.beforePost = { withUnsafeCurrentTask { $0?.cancel() } }
        let cancelled = await Task { @MainActor in await ScheduleService.save(fresh, session: session, store: editor) }
            .value
        HTTPClient.beforePost = nil
        precondition(!cancelled && !editor.isMutating && editor.uncertainSave)
        var bad = draft
        bad.name = "bad\0name"
        precondition(bad.validationError != nil)
        bad = draft
        bad.permissionMode = "bypassPermissions"
        precondition(bad.validationError != nil)
        try await ScheduleCacheTests.run()
        print(
            "PASS schedule disabled defaults, exact cadence/task wire, validation, revision edits, uncertain create/run retry, stale polling and endpoint fences, cancellation recovery, offline retention and run pagination"
        )
    }

    static func run(_ schedule: Schedule, status: String, timestamp: Double) -> [String: Any] {
        [
            "runId": UUID().uuidString, "sessionId": UUID().uuidString, "scheduleId": schedule.id,
            "originSessionId": schedule.originSessionId, "name": schedule.name, "provider": "codex",
            "path": schedule.task.path,
            "scheduledFor": timestamp, "createdAt": timestamp, "status": status,
        ]
    }
}
