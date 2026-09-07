import Foundation

@MainActor enum SessionMcpService {
    static func load(endpoint: Endpoint, threadId: String?, store: SessionMcpStore, more: Bool = false) async {
        let generation = UUID()
        store.generation = generation
        store.isLoading = true
        store.error = nil
        var query = ["detail": "toolsAndAuthOnly", "limit": "50"]
        if let threadId { query["threadId"] = threadId }
        if more, let cursor = store.nextCursor { query["cursor"] = cursor }
        let response = await HTTPClient.get(endpoint: endpoint, path: "/codex/mcp", query: query, timeout: 30)
        if store.generation == generation {
            if !Task.isCancelled, let servers: [SessionMcpServer] = SessionPluginService.decode(response, key: "data") {
                var merged = more ? store.servers : []
                for server in servers {
                    if let index = merged.firstIndex(where: { $0.id == server.id }) {
                        merged[index] = server
                    } else {
                        merged.append(server)
                    }
                }
                store.servers = merged
                if let data = response?.0, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                {
                    store.nextCursor = object["nextCursor"] as? String
                }
            } else if !Task.isCancelled {
                store.error = SessionPluginService.error(response)
            }
            store.isLoading = false
        }
    }
}
