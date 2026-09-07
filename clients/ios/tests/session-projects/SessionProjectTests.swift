import Foundation
import SwiftData

@main struct SessionProjectTests {
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try ModelContainer(
            for: Session.self, Endpoint.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let endpoint = Endpoint()
        let secondEndpoint = Endpoint()
        container.mainContext.insert(endpoint)
        container.mainContext.insert(secondEndpoint)
        let session = Session(endpoint: endpoint)
        container.mainContext.insert(session)
        let root = SessionProjectRoot(path: "/srv/actual-project")
        let project = SessionProject(
            id: "project-a", name: "Product",
            roots: [root, root, SessionProjectRoot(path: "relative"), SessionProjectRoot(path: "~")])
        precondition(project.selectableRoots == [root])
        SessionActions.setProject(project, root: root, endpoint: endpoint, for: session)
        precondition(
            session.provider == .codex && session.path == "/srv/actual-project" && session.codexProjectId == "project-a"
        )
        session.model = ChatModel(rawValue: "chosen-model")
        session.effort = .high
        SessionActions.setProject(project, root: root, endpoint: endpoint, for: session)
        precondition(session.model?.rawValue == "chosen-model" && session.effort == .high)
        SessionActions.setProvider(.codex, for: session)
        precondition(session.codexProjectId == "project-a")
        SessionActions.setPath("/srv/manual", for: session)
        precondition(session.codexProjectId == nil && session.path == "/srv/manual")
        SessionActions.setProject(
            project, root: SessionProjectRoot(path: "/invented"), endpoint: endpoint, for: session)
        precondition(session.path == "/srv/manual")
        SessionActions.setProject(project, root: root, endpoint: endpoint, for: session)
        SessionActions.setEndpoint(secondEndpoint, for: session, clearsPath: true)
        precondition(session.codexProjectId == nil && session.path == nil)
        SessionActions.setProject(project, root: root, endpoint: endpoint, for: session)
        SessionActions.setProvider(.claude, for: session)
        precondition(session.codexProjectId == nil && session.path == root.path)
        session.existsOnServer = true
        SessionActions.setProject(project, root: root, endpoint: endpoint, for: session)
        precondition(session.provider == .claude && session.codexProjectId == nil)
        session.existsOnServer = false
        SessionActions.setProject(project, root: root, endpoint: endpoint, for: session)
        SessionActions.detachEndpoint(for: session)
        precondition(session.endpoint == nil && session.codexProjectId == nil && session.path == root.path)
        let first = SessionProjectPage(data: [project], nextCursor: "page-2")
        HTTPClient.response = (
            try JSONEncoder().encode(first),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        let store = SessionProjectStore()
        await SessionProjectService.load(endpoint: endpoint, store: store, cacheDirectory: directory)
        precondition(store.projects == [project] && store.nextCursor == "page-2" && !store.isCached)
        precondition(HTTPClient.lastEndpointId == endpoint.id)
        let changed = SessionProject(id: "project-a", name: "Updated", roots: [root])
        let second = SessionProject(id: "project-b", name: "Server", roots: [SessionProjectRoot(path: "/opt/server")])
        HTTPClient.response = (
            try JSONEncoder().encode(SessionProjectPage(data: [changed, second], nextCursor: nil)),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        await SessionProjectService.load(endpoint: endpoint, store: store, more: true, cacheDirectory: directory)
        precondition(store.projects == [changed, second] && store.nextCursor == nil)
        precondition(HTTPClient.lastQuery["cursor"] == "page-2")
        HTTPClient.response = nil
        let offline = SessionProjectStore()
        await SessionProjectService.load(endpoint: endpoint, store: offline, cacheDirectory: directory)
        precondition(offline.projects == [changed, second] && offline.isCached && offline.error != nil)
        let isolated = SessionProjectStore()
        await SessionProjectService.load(endpoint: secondEndpoint, store: isolated, cacheDirectory: directory)
        precondition(isolated.projects.isEmpty)
        HTTPClient.response = (
            try JSONEncoder().encode(first),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        var release: CheckedContinuation<Void, Never>?
        HTTPClient.beforeResponse = { await withCheckedContinuation { release = $0 } }
        let stale = Task { @MainActor in
            await SessionProjectService.load(endpoint: endpoint, store: store, cacheDirectory: directory)
        }
        while release == nil { await Task.yield() }
        HTTPClient.beforeResponse = nil
        HTTPClient.response = (
            try JSONEncoder().encode(SessionProjectPage(data: [second], nextCursor: nil)),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        await SessionProjectService.load(endpoint: endpoint, store: store, cacheDirectory: directory)
        release?.resume()
        await stale.value
        precondition(store.projects == [second])
        endpoint.connectionRevision = UUID()
        HTTPClient.response = nil
        await SessionProjectService.load(endpoint: endpoint, store: store, cacheDirectory: directory)
        precondition(store.projects.isEmpty && store.error != nil)
        let preservedOldCache = await SessionProjectService.readCache(endpointId: endpoint.id, directory: directory)
        precondition(preservedOldCache?.data == [second])
        HTTPClient.response = (
            try JSONEncoder().encode(first),
            HTTPURLResponse(
                url: URL(string: "http://localhost")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
        await SessionProjectService.load(endpoint: endpoint, store: store, cacheDirectory: directory)
        let scopedCache = await SessionProjectService.readCache(
            endpointId: endpoint.connectionRevision!, directory: directory)
        precondition(scopedCache?.data == first.data)
        await SessionProjectService.removeCache(endpointId: endpoint.id, directory: directory)
        let removed = await SessionProjectService.readCache(endpointId: endpoint.id, directory: directory)
        precondition(removed == nil)
        print(
            "Passed actual remote-root selection, model preservation, project association clearing, existing-thread protection, pagination overlap, offline cache, endpoint isolation, stale response rejection, and cache removal"
        )
    }
}
