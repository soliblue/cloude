import Foundation

@MainActor enum ScheduleService {
    static func load(endpoint: Endpoint, store: ScheduleStore, cache: ScheduleCache = .shared) async {
        if store.isMutating { return }
        let scope = endpoint.cacheId
        if store.scope != scope {
            store.schedules = []
            store.runs = []
            store.runRequestIds = [:]
            store.scope = scope
            store.isCached = false
            store.available = false
            store.error = nil
            store.nextCursor = nil
        }
        let generation = UUID()
        store.generation = generation
        store.isLoading = true
        defer { if store.generation == generation { store.isLoading = false } }
        let cached = await cache.prepare(endpoint: scope, generation: generation)
        guard endpoint.cacheId == scope, store.generation == generation, !Task.isCancelled else { return }
        if store.schedules.isEmpty, let cached, let page = try? JSONDecoder().decode(SchedulePage.self, from: cached) {
            store.schedules = page.schedules
            store.available = false
            store.isCached = true
        }
        let result = await HTTPClient.get(endpoint: endpoint, path: "/schedules", timeout: 20)
        if endpoint.cacheId == scope && store.generation == generation && !Task.isCancelled {
            if let (data, response) = result, response.statusCode == 200,
                let page = try? JSONDecoder().decode(SchedulePage.self, from: data)
            {
                store.schedules = page.schedules
                store.available = page.available
                store.error = page.error
                store.isCached = false
                await cache.store(data, endpoint: scope, generation: generation)
            } else {
                store.available = false
                store.isCached = !store.schedules.isEmpty
                store.error = error(result, fallback: "Could not refresh schedules. Saved results stay visible.")
            }
        }
    }

    static func loadRuns(
        _ schedule: Schedule, endpoint: Endpoint, store: ScheduleStore, more: Bool = false,
        cache: ScheduleCache = .shared
    ) async {
        if store.isMutating || UUID(uuidString: schedule.id) == nil { return }
        let scope = endpoint.cacheId
        let generation = UUID()
        if store.scope != scope || store.historyId != schedule.id {
            store.runs = []
            store.nextCursor = nil
            store.loadedMoreRuns = false
            store.isCached = false
            store.error = nil
        }
        store.scope = scope
        store.historyId = schedule.id
        store.generation = generation
        store.isLoading = true
        defer { if store.generation == generation { store.isLoading = false } }
        let cached = await cache.prepare(endpoint: scope, historyId: schedule.id, generation: generation)
        guard endpoint.cacheId == scope, store.generation == generation, !Task.isCancelled else { return }
        if store.runs.isEmpty, let cached, let page = try? JSONDecoder().decode(ScheduleRunPage.self, from: cached) {
            store.runs = page.runs
            store.nextCursor = page.nextCursor
            store.loadedMoreRuns = page.runs.count > 50
            store.isCached = true
        }
        var query = ["limit": "50"]
        if more, let cursor = store.nextCursor { query["cursor"] = cursor }
        let result = await HTTPClient.get(
            endpoint: endpoint, path: "/schedules/\(schedule.id)/runs", query: query, timeout: 20)
        if endpoint.cacheId == scope && store.generation == generation && !Task.isCancelled {
            if let (data, response) = result, response.statusCode == 200,
                let page = try? JSONDecoder().decode(ScheduleRunPage.self, from: data)
            {
                if !more && !store.loadedMoreRuns { store.runs = [] }
                for run in page.runs {
                    if let index = store.runs.firstIndex(where: { $0.id == run.id }) {
                        store.runs[index] = run
                    } else {
                        store.runs.append(run)
                    }
                }
                store.runs.sort {
                    $0.scheduledFor == $1.scheduledFor ? $0.runId > $1.runId : $0.scheduledFor > $1.scheduledFor
                }
                if more || !store.loadedMoreRuns {
                    store.nextCursor = page.nextCursor == query["cursor"] ? nil : page.nextCursor
                }
                if more { store.loadedMoreRuns = true }
                store.error = nil
                store.isCached = false
                await cache.store(data, endpoint: scope, historyId: schedule.id, generation: generation, more: more)
            } else {
                store.isCached = !store.runs.isEmpty
                store.error = error(result, fallback: "Could not refresh run history. Check this machine’s connection.")
            }
        }
    }

    static func save(_ draft: ScheduleDraft, session: Session, store: ScheduleStore) async -> Bool {
        if let validation = draft.validationError {
            store.error = validation
            return false
        }
        if let id = draft.scheduleId, UUID(uuidString: id) == nil {
            store.error = "Reload this schedule before editing it."
            return false
        }
        if !store.isMutating, session.connectionKey == draft.connectionKey,
            let endpoint = session.endpoint, endpoint.capabilities?.contains("agentSchedules") == true
        {
            let scope = endpoint.cacheId
            store.isMutating = true
            store.error = nil
            defer { store.isMutating = false }
            let result = await HTTPClient.post(
                endpoint: endpoint, path: draft.scheduleId.map { "/schedules/\($0)/update" } ?? "/schedules",
                body: draft.body, timeout: 30)
            if endpoint.cacheId == scope && session.connectionKey == draft.connectionKey {
                if Task.isCancelled {
                    store.uncertainSave = true
                    store.error = "The save was interrupted. Retry the same request to check its outcome."
                    return false
                }
                if let (_, response) = result, (200..<300).contains(response.statusCode) {
                    store.uncertainSave = false
                    return true
                }
                store.uncertainSave = result == nil || result?.1.statusCode == 408 || (result?.1.statusCode ?? 0) >= 500
                store.error = error(
                    result,
                    fallback:
                        "Could not confirm the save. Retry uses the same request; refresh the list before creating another schedule."
                )
            }
        }
        return false
    }

    static func setEnabled(_ schedule: Schedule, enabled: Bool, endpoint: Endpoint, store: ScheduleStore) async -> Bool
    {
        await mutate(
            schedule, endpoint: endpoint, store: store, path: "/schedules/\(schedule.id)/update",
            body: ["revision": schedule.revision, "enabled": enabled])
    }

    static func remove(_ schedule: Schedule, endpoint: Endpoint, store: ScheduleStore) async -> Bool {
        await mutate(
            schedule, endpoint: endpoint, store: store, path: "/schedules/\(schedule.id)",
            body: ["revision": schedule.revision], deleting: true)
    }

    static func run(_ schedule: Schedule, endpoint: Endpoint, store: ScheduleStore) async -> Bool {
        if store.runRequestIds[schedule.id] == nil { store.runRequestIds[schedule.id] = UUID() }
        let success = await mutate(
            schedule, endpoint: endpoint, store: store, path: "/schedules/\(schedule.id)/run",
            body: ["requestId": store.runRequestIds[schedule.id]!.uuidString])
        if success { store.runRequestIds[schedule.id] = nil }
        return success
    }

    static func mutate(
        _ schedule: Schedule, endpoint: Endpoint, store: ScheduleStore, path: String,
        body: [String: Any], deleting: Bool = false
    ) async -> Bool {
        if !store.isMutating, store.scope == endpoint.cacheId, UUID(uuidString: schedule.id) != nil,
            endpoint.capabilities?.contains("agentSchedules") == true
        {
            let scope = endpoint.cacheId
            store.generation = UUID()
            store.isLoading = false
            store.isMutating = true
            store.error = nil
            defer { store.isMutating = false }
            let result =
                deleting
                ? await HTTPClient.delete(endpoint: endpoint, path: path, body: body, timeout: 30)
                : await HTTPClient.post(endpoint: endpoint, path: path, body: body, timeout: 30)
            if endpoint.cacheId == scope && store.scope == scope && !Task.isCancelled {
                store.isMutating = false
                if let (_, response) = result, (200..<300).contains(response.statusCode) { return true }
                store.error = error(result, fallback: "Could not confirm this change. Refresh before trying again.")
            }
        }
        return false
    }

    static func error(_ result: (Data, HTTPURLResponse)?, fallback: String) -> String {
        if let (data, response) = result {
            if response.statusCode == 409 {
                return "This schedule changed or already has a run in progress. Refresh to see its current state."
            }
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let message = object["error"] as? String, !message.isEmpty
            {
                return message
            }
        }
        return fallback
    }
}
