import Foundation

@MainActor enum SessionSectionService {
    static func load(endpoint: Endpoint, store: SessionSectionStore, more: Bool = false) async {
        if store.scope != endpoint.cacheId {
            store.isMutating = false
            store.sections = []
            store.nextCursor = nil
            store.scope = endpoint.cacheId
        }
        if store.isMutating { return }
        let scope = endpoint.cacheId
        let generation = UUID()
        store.generation = generation
        store.isLoading = true
        store.error = nil
        var query = ["limit": "100"]
        if more, let cursor = store.nextCursor { query["cursor"] = cursor }
        let response = await HTTPClient.get(endpoint: endpoint, path: "/codex/sections", query: query, timeout: 20)
        if endpoint.cacheId == scope && store.scope == scope && store.generation == generation {
            if let (data, response) = response, response.statusCode == 200, !Task.isCancelled,
                let page = try? JSONDecoder().decode(SessionSectionPage.self, from: data)
            {
                if !more { store.sections = [] }
                for section in page.data {
                    if let index = store.sections.firstIndex(where: { $0.id == section.id }) {
                        store.sections[index] = section
                    } else {
                        store.sections.append(section)
                    }
                }
                store.nextCursor = page.nextCursor == query["cursor"] ? nil : page.nextCursor
            } else if !Task.isCancelled {
                store.error = "Could not load sections. Check this machine’s connection and Codex sign-in."
            }
            store.isLoading = false
        }
    }

    static func save(name: String, sectionId: String?, endpoint: Endpoint, store: SessionSectionStore) async -> Bool {
        if !SessionSectionStore.validName(name) {
            store.error = "Enter a section name of 1 to 120 characters."
            return false
        }
        if let sectionId, !SessionSection.validIdentifier(sectionId) {
            store.error = "This section has an invalid identifier. Reload sections."
            return false
        }
        let path =
            sectionId.map {
                "/codex/sections/\($0)/update"
            } ?? "/codex/sections"
        return await mutate(
            endpoint: endpoint, store: store, path: path,
            body: ["name": name.trimmingCharacters(in: .whitespacesAndNewlines)])
    }

    static func remove(_ section: SessionSection, endpoint: Endpoint, store: SessionSectionStore) async -> Bool {
        if !SessionSection.validIdentifier(section.id) {
            store.error = "This section has an invalid identifier. Reload sections."
            return false
        }
        return await mutate(
            endpoint: endpoint, store: store,
            path: "/codex/sections/\(section.id)",
            body: [:], deleting: true)
    }

    static func move(session: Session, sectionId: String?, store: SessionSectionStore) async -> Bool {
        if let endpoint = session.endpoint, session.provider == .codex, session.existsOnServer,
            endpoint.capabilities?.contains("codexSections") == true, !store.isMutating
        {
            let scope = endpoint.cacheId
            let sessionKey = session.connectionKey
            store.isMutating = true
            store.error = nil
            store.generation = UUID()
            let response = await HTTPClient.post(
                endpoint: endpoint, path: "/sessions/\(session.id.uuidString)/section",
                body: ["sectionId": sectionId as Any? ?? NSNull()], timeout: 20)
            if endpoint.cacheId == scope && session.connectionKey == sessionKey {
                store.isMutating = false
                if let (_, response) = response, response.statusCode == 200 { return true }
                store.error =
                    "Could not confirm the move. Refresh remote history to check its section before trying again."
            }
        }
        return false
    }

    static func mutate(
        endpoint: Endpoint, store: SessionSectionStore, path: String, body: [String: Any], deleting: Bool = false
    ) async -> Bool {
        if endpoint.capabilities?.contains("codexSections") == true, !store.isMutating {
            let scope = endpoint.cacheId
            let generation = UUID()
            store.scope = scope
            store.generation = generation
            store.isMutating = true
            store.error = nil
            let result =
                deleting
                ? await HTTPClient.delete(endpoint: endpoint, path: path, body: body, timeout: 20)
                : await HTTPClient.post(endpoint: endpoint, path: path, body: body, timeout: 20)
            if endpoint.cacheId == scope && store.generation == generation {
                store.isMutating = false
                let succeeded = result?.1.statusCode == 200
                await load(endpoint: endpoint, store: store)
                if endpoint.cacheId == scope && !succeeded {
                    store.error =
                        "The change could not be confirmed. Check the section list before trying again."
                }
                return succeeded && endpoint.cacheId == scope
            }
        }
        return false
    }
}
