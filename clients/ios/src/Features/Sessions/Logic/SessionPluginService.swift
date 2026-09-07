import Foundation

@MainActor enum SessionPluginService {
    static func decode<T: Decodable>(_ response: (Data, HTTPURLResponse)?, key: String) -> T? {
        if let (data, response) = response, response.statusCode == 200,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let value = object[key], let encoded = try? JSONSerialization.data(withJSONObject: value)
        {
            return try? JSONDecoder().decode(T.self, from: encoded)
        }
        return nil
    }

    static func error(_ response: (Data, HTTPURLResponse)?) -> String {
        response.flatMap { try? JSONSerialization.jsonObject(with: $0.0) as? [String: Any] }?["error"] as? String
            ?? "Could not refresh this machine. Check the connection and try again."
    }

    @concurrent static func catalog(_ data: Data) async -> SessionPluginCatalog? {
        try? JSONDecoder().decode(SessionPluginCatalog.self, from: data)
    }

    static func load(
        endpoint: Endpoint, path: String?, installed: Bool, store: SessionPluginStore, force: Bool = false
    ) async {
        let generation = UUID()
        store.generation = generation
        store.isLoading = true
        store.error = nil
        var query = ["installed": String(installed)]
        if !installed { query["forceRefetch"] = String(force) }
        if let path { query["path"] = path }
        let response = await HTTPClient.get(endpoint: endpoint, path: "/codex/plugins", query: query, timeout: 30)
        let catalog: SessionPluginCatalog?
        if let (data, http) = response, http.statusCode == 200 {
            catalog = await self.catalog(data)
        } else {
            catalog = nil
        }
        if store.generation == generation {
            if !Task.isCancelled, let catalog {
                var seen = Set<String>()
                store.entries = catalog.marketplaces.flatMap { marketplace in
                    marketplace.plugins.filter { !installed || $0.installed }.map {
                        SessionPluginEntry(plugin: $0, marketplace: marketplace.name, marketplacePath: marketplace.path)
                    }
                }.filter { seen.insert($0.id).inserted }
                if catalog.marketplaceLoadErrors?.isEmpty == false {
                    store.error = "Some marketplaces could not load. Refresh to try again."
                }
            } else if !Task.isCancelled {
                store.error = error(response)
            }
            store.isLoading = false
        }
    }

    static func detail(_ entry: SessionPluginEntry, endpoint: Endpoint, store: SessionPluginDetailStore) async {
        if !store.isMutating {
            let generation = UUID()
            store.generation = generation
            store.isLoading = true
            store.error = nil
            let response = await HTTPClient.get(
                endpoint: endpoint, path: "/codex/plugin", query: entry.parameters.compactMapValues { $0 as? String },
                timeout: 30)
            if store.generation == generation {
                if !Task.isCancelled, let detail: SessionPluginDetail = decode(response, key: "plugin") {
                    store.detail = detail
                    store.installed = detail.summary.installed
                } else if !Task.isCancelled {
                    store.error = error(response)
                }
                store.isLoading = false
            }
        }
    }

    static func install(_ entry: SessionPluginEntry, endpoint: Endpoint, store: SessionPluginDetailStore) async {
        if !store.isMutating, store.detail?.summary.canInstall == true, store.installed != true {
            let generation = UUID()
            store.generation = generation
            store.isMutating = true
            store.error = nil
            var body = entry.parameters
            body["installAttemptId"] = store.installAttemptId.uuidString
            let response = await HTTPClient.post(endpoint: endpoint, path: "/codex/plugin", body: body, timeout: 90)
            if store.generation == generation {
                if let apps: [SessionApp] = decode(response, key: "appsNeedingAuth") {
                    store.appsNeedingAuth = apps
                    store.installed = true
                    store.installAttemptId = UUID()
                } else {
                    let verified = await HTTPClient.get(
                        endpoint: endpoint, path: "/codex/plugin",
                        query: entry.parameters.compactMapValues { $0 as? String }, timeout: 30)
                    if store.generation == generation {
                        if let detail: SessionPluginDetail = decode(verified, key: "plugin") {
                            store.detail = detail
                            store.installed = detail.summary.installed
                        }
                        store.error = error(response)
                    }
                }
                if store.generation == generation { store.isMutating = false }
            }
        }
    }

    static func uninstall(_ entry: SessionPluginEntry, endpoint: Endpoint, store: SessionPluginDetailStore) async {
        if !store.isMutating, store.installed == true, store.detail?.summary.installPolicySource != "WORKSPACE_SETTING"
        {
            let generation = UUID()
            store.generation = generation
            store.isMutating = true
            store.error = nil
            let response = await HTTPClient.delete(
                endpoint: endpoint, path: "/codex/plugin", body: ["pluginId": entry.plugin.id], timeout: 60)
            if store.generation == generation {
                store.isMutating = false
                if let (_, response) = response, response.statusCode == 200 {
                    store.installed = false
                    store.appsNeedingAuth = []
                    await detail(entry, endpoint: endpoint, store: store)
                } else {
                    store.error = "Could not remove the plugin. Refresh its status and try again."
                }
            }
        }
    }
}
