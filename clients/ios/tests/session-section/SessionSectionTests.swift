import Foundation
import SwiftData

@main struct SessionSectionTests {
    @MainActor static func main() async {
        let endpoint = Endpoint()
        let store = SessionSectionStore()
        HTTPClient.getResponse = HTTPClient.response([
            "data": [["id": "one", "name": "Work", "appearance": ["color": "blue"]]], "nextCursor": "page2",
        ])
        await SessionSectionService.load(endpoint: endpoint, store: store)
        precondition(store.sections == [SessionSection(id: "one", name: "Work")] && store.nextCursor == "page2")
        HTTPClient.getResponse = HTTPClient.response([
            "data": [["id": "one", "name": "Renamed"], ["id": "two", "name": "Personal"]]
        ])
        await SessionSectionService.load(endpoint: endpoint, store: store, more: true)
        precondition(store.sections.count == 2 && store.sections[0].name == "Renamed" && store.nextCursor == nil)
        precondition(HTTPClient.requests.last?.2["cursor"] as? String == "page2")
        HTTPClient.getResponse = nil
        await SessionSectionService.load(endpoint: endpoint, store: store)
        precondition(store.sections.count == 2 && store.error != nil)
        HTTPClient.getResponse = HTTPClient.response(["data": [["id": "wrong", "name": "Old host"]]])
        HTTPClient.beforeGet = { endpoint.connectionRevision = UUID() }
        await SessionSectionService.load(endpoint: endpoint, store: store)
        precondition(!store.sections.contains(where: { $0.id == "wrong" }))
        HTTPClient.beforeGet = nil
        HTTPClient.getResponse = HTTPClient.response(["data": []])
        await SessionSectionService.load(endpoint: endpoint, store: store)
        precondition(store.sections.isEmpty && store.scope == endpoint.cacheId)
        for name in ["", " \n", "a\0b", String(repeating: "a", count: 121)] {
            precondition(!SessionSectionStore.validName(name))
        }
        HTTPClient.postResponse = HTTPClient.response(["section": ["id": "new", "name": "New"]])
        HTTPClient.getResponse = HTTPClient.response(["data": [["id": "new", "name": "New"]]])
        let created = await SessionSectionService.save(
            name: "  New  ", sectionId: nil, endpoint: endpoint, store: store)
        precondition(created && store.sections.first?.name == "New")
        precondition(HTTPClient.requests.first(where: { $0.0 == "POST" })?.2["name"] as? String == "New")
        HTTPClient.requests = []
        HTTPClient.postResponse = nil
        let uncertain = await SessionSectionService.save(name: "New", sectionId: nil, endpoint: endpoint, store: store)
        precondition(!uncertain && store.error != nil && HTTPClient.requests.filter { $0.0 == "POST" }.count == 1)
        precondition(HTTPClient.requests.last?.0 == "GET" && store.sections.count == 1)
        HTTPClient.postResponse = HTTPClient.response([:])
        HTTPClient.requests = []
        HTTPClient.beforePost = {
            let duplicate = await SessionSectionService.save(
                name: "Duplicate", sectionId: nil, endpoint: endpoint, store: store)
            precondition(!duplicate)
        }
        let serialized = await SessionSectionService.save(
            name: "One request", sectionId: nil, endpoint: endpoint, store: store)
        precondition(serialized && HTTPClient.requests.filter { $0.0 == "POST" }.count == 1)
        HTTPClient.beforePost = nil
        HTTPClient.requests = []
        _ = await SessionSectionService.save(name: "Better", sectionId: "new", endpoint: endpoint, store: store)
        precondition(HTTPClient.requests[0].1 == "/codex/sections/new/update" && HTTPClient.requests[0].2.count == 1)
        _ = await SessionSectionService.remove(SessionSection(id: "new", name: "New"), endpoint: endpoint, store: store)
        precondition(HTTPClient.requests.contains(where: { $0.0 == "DELETE" && $0.1 == "/codex/sections/new" }))
        HTTPClient.requests = []
        _ = await SessionSectionService.save(
            name: "Renamed", sectionId: "01a078f9-5a00-7360-8478-c8b342cb23aa", endpoint: endpoint, store: store)
        precondition(HTTPClient.requests[0].1 == "/codex/sections/01a078f9-5a00-7360-8478-c8b342cb23aa/update")
        _ = await SessionSectionService.remove(
            SessionSection(id: "01a078f9-5a00-7360-8478-c8b342cb23aa", name: "Renamed"), endpoint: endpoint,
            store: store)
        precondition(
            HTTPClient.requests.contains(where: {
                $0.0 == "DELETE" && $0.1 == "/codex/sections/01a078f9-5a00-7360-8478-c8b342cb23aa"
            }))
        HTTPClient.requests = []
        for identifier in ["", "../delete", "a/b", "a%2Fb", "x?delete=true", "a b"] {
            let saved = await SessionSectionService.save(
                name: "Unsafe", sectionId: identifier, endpoint: endpoint, store: store)
            let removed = await SessionSectionService.remove(
                SessionSection(id: identifier, name: "Unsafe"), endpoint: endpoint, store: store)
            precondition(!saved && !removed && HTTPClient.requests.isEmpty)
        }
        let session = Session(endpoint: endpoint, path: "/repo")
        session.provider = .codex
        session.existsOnServer = true
        let cleared = await SessionSectionService.move(session: session, sectionId: nil, store: store)
        precondition(cleared)
        precondition(HTTPClient.requests.last?.2["sectionId"] is NSNull)
        let moved = await SessionSectionService.move(session: session, sectionId: "new", store: store)
        precondition(moved)
        precondition(HTTPClient.requests.last?.2["sectionId"] as? String == "new")
        HTTPClient.beforePost = { endpoint.connectionRevision = UUID() }
        let stale = await SessionSectionService.move(session: session, sectionId: "new", store: store)
        precondition(!stale)
        HTTPClient.beforePost = nil
        await SessionSectionService.load(endpoint: endpoint, store: store)
        precondition(!store.isMutating)
        let count = HTTPClient.requests.count
        endpoint.capabilities = []
        let blocked = await SessionSectionService.save(
            name: "Blocked", sectionId: nil, endpoint: endpoint, store: store)
        precondition(!blocked)
        precondition(HTTPClient.requests.count == count)
        precondition(SessionSectionFilter.all.query.isEmpty)
        precondition(SessionSectionFilter.unsectioned.query == ["unsectioned": "true"])
        precondition(SessionSectionFilter.section("abc").query == ["sectionId": "abc"])
        print(
            "PASS sections pagination/dedup/offline scope, stale revisions, name validation, create uncertainty without retry, name-only rename, DELETE, null move, capabilities and exclusive history filters"
        )
    }
}
