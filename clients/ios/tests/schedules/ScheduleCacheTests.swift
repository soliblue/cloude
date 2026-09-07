import Foundation

@MainActor enum ScheduleCacheTests {
    static func run() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ScheduleCache(root: root)
        let endpoint = Endpoint()
        endpoint.capabilities = ["agentSchedules"]
        let scope = endpoint.cacheId
        let id = UUID().uuidString
        var job: [String: Any] = [
            "id": id, "name": "Saved schedule", "enabled": false, "originSessionId": UUID().uuidString,
            "task": ["provider": "codex", "path": "/fixture", "prompt": "Check", "permissionMode": "default"],
            "schedule": ["kind": "interval", "minutes": 60], "revision": 1, "createdAt": 1000, "updatedAt": 1000,
        ]
        let schedule = try JSONDecoder().decode(Schedule.self, from: JSONSerialization.data(withJSONObject: job))
        HTTPClient.beforeGet = nil
        HTTPClient.getResponse = HTTPClient.response(["schedules": [job], "available": true])
        await ScheduleService.load(endpoint: endpoint, store: ScheduleStore(), cache: cache)
        HTTPClient.getResponse = nil
        let cold = ScheduleStore()
        await ScheduleService.load(endpoint: endpoint, store: cold, cache: ScheduleCache(root: root))
        precondition(cold.schedules.first?.name == "Saved schedule" && cold.isCached && !cold.available)
        let runRows = (0..<75).map { ScheduleTests.run(schedule, status: "completed", timestamp: Double(1000 + $0)) }
        HTTPClient.getResponse = HTTPClient.response([
            "runs": Array(runRows.suffix(50)), "nextCursor": runRows[25]["runId"]!,
        ])
        let history = ScheduleStore()
        await ScheduleService.loadRuns(schedule, endpoint: endpoint, store: history, cache: cache)
        HTTPClient.getResponse = HTTPClient.response(["runs": Array(runRows.prefix(25))])
        await ScheduleService.loadRuns(schedule, endpoint: endpoint, store: history, more: true, cache: cache)
        HTTPClient.getResponse = nil
        let coldHistory = ScheduleStore()
        await ScheduleService.loadRuns(
            schedule, endpoint: endpoint, store: coldHistory, cache: ScheduleCache(root: root))
        precondition(
            coldHistory.runs.count == 75 && coldHistory.loadedMoreRuns && coldHistory.nextCursor == nil
                && coldHistory.isCached)
        let boundedRunsGeneration = UUID()
        _ = await cache.prepare(endpoint: scope, historyId: id, generation: boundedRunsGeneration)
        let excessRuns = (0..<125).map {
            ScheduleTests.run(schedule, status: "completed", timestamp: Double(2000 + $0))
        }
        await cache.store(
            HTTPClient.response(["runs": excessRuns]).0, endpoint: scope, historyId: id,
            generation: boundedRunsGeneration)
        let boundedHistory = await cache.read(endpoint: scope, historyId: id)!
        let boundedPage = try JSONDecoder().decode(ScheduleRunPage.self, from: boundedHistory)
        precondition(boundedPage.runs.count == 100 && boundedPage.runs.first?.scheduledFor == 2124)
        let permissions = try FileManager.default.attributesOfItem(
            atPath: root.appendingPathComponent(scope.uuidString).appendingPathComponent("schedules.json").path)
        precondition((permissions[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        let other = Endpoint()
        await ScheduleService.load(endpoint: other, store: cold, cache: cache)
        precondition(cold.schedules.isEmpty && !cold.isCached && cold.scope == other.cacheId)
        job["revision"] = 2
        HTTPClient.getResponse = HTTPClient.response(["schedules": [job], "available": true])
        HTTPClient.beforeGet = { endpoint.connectionRevision = UUID() }
        await ScheduleService.load(endpoint: endpoint, store: ScheduleStore(), cache: cache)
        HTTPClient.beforeGet = nil
        let preserved = await cache.read(endpoint: scope)!
        let preservedPage = try JSONDecoder().decode(SchedulePage.self, from: preserved)
        precondition(preservedPage.schedules[0].revision == 1)
        let freshScope = endpoint.cacheId
        job["revision"] = 3
        let latestResponse = HTTPClient.response(["schedules": [job], "available": true])
        HTTPClient.beforeGet = {
            HTTPClient.beforeGet = nil
            HTTPClient.getResponse = latestResponse
            await ScheduleService.load(endpoint: endpoint, store: ScheduleStore(), cache: cache)
        }
        await ScheduleService.load(endpoint: endpoint, store: ScheduleStore(), cache: cache)
        let latest = await cache.read(endpoint: freshScope)!
        let latestPage = try JSONDecoder().decode(SchedulePage.self, from: latest)
        precondition(latestPage.schedules[0].revision == 3)
        HTTPClient.beforeGet = { withUnsafeCurrentTask { $0?.cancel() } }
        _ = await Task { @MainActor in
            await ScheduleService.load(endpoint: endpoint, store: ScheduleStore(), cache: cache)
        }.value
        HTTPClient.beforeGet = nil
        let afterCancel = await cache.read(endpoint: freshScope)!
        precondition(afterCancel == latest)
        try Data("not JSON".utf8).write(
            to: root.appendingPathComponent(scope.uuidString).appendingPathComponent("schedules.json"))
        endpoint.connectionRevision = nil
        HTTPClient.getResponse = nil
        let corrupted = ScheduleStore()
        await ScheduleService.load(endpoint: endpoint, store: corrupted, cache: cache)
        precondition(corrupted.schedules.isEmpty && !corrupted.isCached && corrupted.error != nil)
        let bounded = ScheduleCache(root: root.appendingPathComponent("bounded"), maxBytes: 5000, maxFiles: 2)
        for _ in 0..<4 {
            let scope = UUID()
            let generation = UUID()
            _ = await bounded.prepare(endpoint: scope, generation: generation)
            await bounded.store(latest, endpoint: scope, generation: generation)
        }
        let files = FileManager.default.enumerator(
            at: root.appendingPathComponent("bounded"), includingPropertiesForKeys: [.isRegularFileKey])!
            .compactMap { $0 as? URL }.filter {
                (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }
        precondition(files.count <= 2)
        let byteCount = files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        precondition(byteCount <= 5000)
        await cache.remove(endpoint: freshScope)
        let removed = await cache.read(endpoint: freshScope)
        precondition(removed == nil)
        print(
            "PASS schedule disk cache cold list/history, endpoint isolation, corruption, stale/concurrent/canceled write fences and retention"
        )
    }
}
