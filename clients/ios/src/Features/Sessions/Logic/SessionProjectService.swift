import Foundation

@MainActor
enum SessionProjectService {
    static func load(
        endpoint: Endpoint, store: SessionProjectStore, more: Bool = false,
        cacheDirectory: URL = URL.applicationSupportDirectory.appendingPathComponent(
            "ProjectCatalog", isDirectory: true)
    ) async {
        let endpointId = endpoint.connectionRevision ?? endpoint.id
        if store.cacheScope != endpointId {
            store.cacheScope = endpointId
            store.projects = []
            store.nextCursor = nil
            store.isCached = false
        }
        let generation = UUID()
        store.generation = generation
        store.isLoading = true
        store.error = nil
        if !more && store.projects.isEmpty,
            let cached = await readCache(endpointId: endpointId, directory: cacheDirectory),
            store.generation == generation, (endpoint.connectionRevision ?? endpoint.id) == endpointId,
            !Task.isCancelled
        {
            store.apply(cached, cached: true)
        }
        let response = await HTTPClient.get(
            endpoint: endpoint, path: "/codex/projects",
            query: more ? store.nextCursor.map { ["cursor": $0] } ?? [:] : [:], timeout: 15)
        if store.generation == generation && (endpoint.connectionRevision ?? endpoint.id) == endpointId {
            if let (data, response) = response, response.statusCode == 200, !Task.isCancelled,
                let page = try? JSONDecoder().decode(SessionProjectPage.self, from: data)
            {
                store.apply(page, append: more)
                await writeCache(
                    SessionProjectPage(data: store.projects, nextCursor: store.nextCursor),
                    endpointId: endpointId, directory: cacheDirectory)
            } else if !Task.isCancelled {
                store.error = "Projects could not refresh. You can use saved locations or browse remote folders."
                store.isCached = !store.projects.isEmpty
            }
        }
        if store.generation == generation { store.isLoading = false }
    }

    @concurrent
    static func readCache(endpointId: UUID, directory: URL) async -> SessionProjectPage? {
        (try? Data(contentsOf: directory.appendingPathComponent(endpointId.uuidString + ".json"))).flatMap {
            try? JSONDecoder().decode(SessionProjectPage.self, from: $0)
        }
    }

    @concurrent
    static func writeCache(_ page: SessionProjectPage, endpointId: UUID, directory: URL) async {
        if let data = try? JSONEncoder().encode(page) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: directory.appendingPathComponent(endpointId.uuidString + ".json"), options: .atomic)
        }
    }

    @concurrent
    static func removeCache(
        endpointId: UUID,
        directory: URL = URL.applicationSupportDirectory.appendingPathComponent("ProjectCatalog", isDirectory: true)
    ) async {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(endpointId.uuidString + ".json"))
    }
}
