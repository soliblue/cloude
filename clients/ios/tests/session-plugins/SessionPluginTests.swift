import Foundation

@main struct SessionPluginTests {
    @MainActor static func main() async {
        let endpoint = Endpoint()
        let store = SessionPluginStore()
        let plugin: [String: Any] = [
            "id": "test@market", "name": "test", "installed": false, "enabled": false, "installPolicy": "AVAILABLE",
            "authPolicy": "ON_INSTALL", "mustShowInstallationInterstitial": true,
            "interface": ["displayName": "Test Plugin", "capabilities": ["Tools"]],
        ]
        let installedPlugin = plugin.merging(["installed": true, "enabled": true]) { _, new in new }
        HTTPClient.getResponses["/codex/plugins"] = HTTPClient.response([
            "marketplaces": [
                ["name": "market", "path": NSNull(), "plugins": [installedPlugin, installedPlugin, plugin]]
            ], "marketplaceLoadErrors": [["marketplacePath": "/broken", "message": "Unavailable"]],
        ])
        await SessionPluginService.load(endpoint: endpoint, path: "/repo", installed: true, store: store)
        precondition(store.entries.count == 1 && store.error != nil)
        precondition(HTTPClient.queries.last?["forceRefetch"] == nil)
        precondition(store.entries[0].parameters["remoteMarketplaceName"] as? String == "market")
        HTTPClient.getResponses["/codex/plugins"] = nil
        await SessionPluginService.load(endpoint: endpoint, path: "/repo", installed: true, store: store)
        precondition(store.entries.count == 1 && store.error != nil)
        let detail: [String: Any] = [
            "summary": plugin, "description": "Test capabilities",
            "skills": [["name": "test", "description": "Does work", "enabled": true]],
            "apps": [["id": "app", "name": "App"]], "mcpServers": ["server"],
            "hooks": [["key": "hook", "eventName": "SessionStart"]],
        ]
        HTTPClient.getResponses["/codex/plugin"] = HTTPClient.response(["plugin": detail])
        let entry = SessionPluginEntry(
            plugin: try! JSONDecoder().decode(SessionPlugin.self, from: JSONSerialization.data(withJSONObject: plugin)),
            marketplace: "market", marketplacePath: "/marketplace.json")
        precondition(
            entry.parameters["marketplacePath"] as? String == "/marketplace.json"
                && entry.parameters["remoteMarketplaceName"] == nil)
        let details = SessionPluginDetailStore()
        await SessionPluginService.detail(entry, endpoint: endpoint, store: details)
        precondition(
            details.detail?.summary.canInstall == true
                && details.detail?.summary.mustShowInstallationInterstitial == true)
        HTTPClient.postResponses["/codex/plugin"] = HTTPClient.response([
            "appsNeedingAuth": [["id": "app", "name": "App", "installUrl": "https://chatgpt.com/apps/app"]],
            "authPolicy": "ON_INSTALL",
        ])
        HTTPClient.beforePost = {
            await SessionPluginService.install(entry, endpoint: endpoint, store: details)
            await SessionPluginService.detail(entry, endpoint: endpoint, store: details)
        }
        await SessionPluginService.install(entry, endpoint: endpoint, store: details)
        HTTPClient.beforePost = nil
        precondition(HTTPClient.bodies.count == 1 && details.installed == true)
        precondition(details.appsNeedingAuth.first?.installURL?.host == "chatgpt.com")
        precondition(
            HTTPClient.bodies.last?["pluginName"] as? String == "test"
                && HTTPClient.bodies.last?["installAttemptId"] is String)
        precondition(URLProtocol.registerClass(SessionPluginURLProtocol.self))
        await SessionPluginService.uninstall(entry, endpoint: endpoint, store: details)
        precondition(details.installed == false && details.appsNeedingAuth.isEmpty)
        precondition(
            SessionPluginURLProtocol.captured?.httpMethod == "DELETE"
                && SessionPluginURLProtocol.captured?.value(forHTTPHeaderField: "Authorization") == "Bearer test")
        URLProtocol.unregisterClass(SessionPluginURLProtocol.self)
        HTTPClient.postResponses["/codex/plugin"] = nil
        HTTPClient.getResponses["/codex/plugin"] = HTTPClient.response([
            "plugin": detail.merging(["summary": installedPlugin]) { _, new in new }
        ])
        await SessionPluginService.install(entry, endpoint: endpoint, store: details)
        precondition(details.installed == true && details.error != nil)
        let attempts = HTTPClient.bodies.count
        await SessionPluginService.install(entry, endpoint: endpoint, store: details)
        precondition(HTTPClient.bodies.count == attempts)
        for changes in [
            ["installPolicy": "NOT_AVAILABLE"], ["availability": "DISABLED_BY_ADMIN"],
            ["disabledReason": "plan_not_eligible"],
        ] {
            let value = try! JSONDecoder().decode(
                SessionPlugin.self,
                from: JSONSerialization.data(withJSONObject: plugin.merging(changes) { _, new in new }))
            precondition(!value.canInstall && value.policyDescription != nil)
        }
        for url in ["javascript:alert(1)", "http://chatgpt.com", "https://user:pass@chatgpt.com", "https:///"] {
            let app = try! JSONDecoder().decode(
                SessionApp.self,
                from: JSONSerialization.data(withJSONObject: ["id": "app", "name": "App", "installUrl": url]))
            precondition(app.installURL == nil)
        }
        let appStore = SessionAppStore()
        HTTPClient.getResponses["/codex/apps"] = HTTPClient.response([
            "apps": (0..<105).map { ["id": "app\($0)", "enabled": true, "callable": $0 % 2 == 0] as [String: Any] }
        ])
        HTTPClient.postResponses["/codex/apps/read"] = HTTPClient.response([
            "apps": [
                [
                    "id": "app0", "name": "Resolved name",
                    "toolSummaries": [["name": "read", "description": "Read content", "isReadOnly": true]],
                ]
            ], "missingAppIds": [],
        ])
        let bodiesBefore = HTTPClient.bodies.count
        await SessionAppService.load(endpoint: endpoint, threadId: "thread", store: appStore, force: true)
        precondition(appStore.apps.count == 105 && appStore.metadata["app0"]?.name == "Resolved name")
        precondition(HTTPClient.bodies.count == bodiesBefore + 2)
        precondition(
            (HTTPClient.bodies[bodiesBefore]["appIds"] as? [String])?.count == 100
                && (HTTPClient.bodies.last?["appIds"] as? [String])?.count == 5)
        precondition(HTTPClient.queries.last?["forceRefresh"] == "true" && HTTPClient.queries.last?["cursor"] == nil)
        HTTPClient.postResponses["/codex/apps/read"] = nil
        await SessionAppService.load(endpoint: endpoint, threadId: nil, store: appStore)
        precondition(
            appStore.apps.count == 105 && appStore.metadata["app0"]?.name == "Resolved name" && appStore.error != nil)
        let mcp = SessionMcpStore()
        HTTPClient.getResponses["/codex/mcp"] = HTTPClient.response([
            "data": [["name": "one", "authStatus": "notLoggedIn", "tools": [:]]], "nextCursor": "next",
        ])
        await SessionMcpService.load(endpoint: endpoint, threadId: "thread", store: mcp)
        precondition(mcp.servers.first?.requiresSignIn == true && mcp.nextCursor == "next")
        HTTPClient.getResponses["/codex/mcp"] = HTTPClient.response([
            "data": [
                [
                    "name": "one", "authStatus": "oAuth", "runtimeStatus": "connected",
                    "tools": ["read": ["name": "read"]],
                ], ["name": "two", "authStatus": "unsupported", "tools": [:]],
            ]
        ])
        await SessionMcpService.load(endpoint: endpoint, threadId: "thread", store: mcp, more: true)
        precondition(mcp.servers.count == 2 && mcp.servers[0].status == "Connected" && mcp.nextCursor == nil)
        precondition(HTTPClient.queries.last?["cursor"] == "next")
        HTTPClient.beforeGet = { mcp.generation = UUID() }
        HTTPClient.getResponses["/codex/mcp"] = HTTPClient.response(["data": []])
        await SessionMcpService.load(endpoint: endpoint, threadId: "thread", store: mcp)
        precondition(mcp.servers.count == 2)
        HTTPClient.beforeGet = nil
        let large = (0..<3500).map { index in
            plugin.merging(["id": "plugin\(index)", "name": "plugin\(index)"]) { _, new in new }
        }
        HTTPClient.getResponses["/codex/plugins"] = HTTPClient.response([
            "marketplaces": [["name": "market", "plugins": large]]
        ])
        let start = ContinuousClock.now
        await SessionPluginService.load(endpoint: endpoint, path: "/repo", installed: false, store: store)
        let matches = store.entries.filter { $0.plugin.name.localizedCaseInsensitiveContains("plugin34") }
        precondition(store.entries.count == 3500 && matches.count == 111)
        print(
            "PASS plugin policies, remote/local identities, partial/offline inventory, install receipt and lost response, signed removal, URL validation, app batches, MCP paging/status/stale results; 3500 plugin decode+search \(start.duration(to: .now))"
        )
    }
}
