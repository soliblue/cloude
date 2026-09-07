import Foundation

@MainActor enum SessionAppService {
    static func load(endpoint: Endpoint, threadId: String?, store: SessionAppStore, force: Bool = false) async {
        let generation = UUID()
        store.generation = generation
        store.isLoading = true
        store.error = nil
        var query = ["installed": "true", "forceRefresh": String(force)]
        if let threadId { query["threadId"] = threadId }
        let response = await HTTPClient.get(endpoint: endpoint, path: "/codex/apps", query: query, timeout: 30)
        if store.generation == generation, !Task.isCancelled {
            if let apps: [SessionAppRuntime] = SessionPluginService.decode(response, key: "apps") {
                var seen = Set<String>()
                store.apps = apps.filter { seen.insert($0.id).inserted }
                for start in stride(from: 0, to: store.apps.count, by: 100) {
                    var body: [String: Any] = [
                        "appIds": Array(store.apps[start..<min(start + 100, store.apps.count)]).map(\.id),
                        "includeTools": true,
                    ]
                    if let threadId { body["threadId"] = threadId }
                    let response = await HTTPClient.post(
                        endpoint: endpoint, path: "/codex/apps/read", body: body, timeout: 30)
                    if store.generation == generation, !Task.isCancelled {
                        if let metadata: [SessionApp] = SessionPluginService.decode(response, key: "apps") {
                            for app in metadata { store.metadata[app.id] = app }
                        } else {
                            store.error = "Some app details could not refresh. Pull to try again."
                        }
                    } else {
                        break
                    }
                }
            } else {
                store.error = SessionPluginService.error(response)
            }
        }
        if store.generation == generation { store.isLoading = false }
    }
}
