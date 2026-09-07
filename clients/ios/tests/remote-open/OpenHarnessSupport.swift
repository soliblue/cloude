import Foundation
import SwiftData

@Model
final class Endpoint {
    @Attribute(.unique) var id: UUID
    var connectionRevision: UUID?
    var capabilities: [String]? = nil
    var host = "fixture"
    var port = 8765
    var transportScheme = "http"

    init(id: UUID = UUID(), revision: UUID? = nil) {
        self.id = id
        connectionRevision = revision
    }

    var cacheId: UUID { connectionRevision ?? id }
}

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var endpoint: Endpoint?
    var codexThreadId: String?
    var parentSessionId: UUID?
    var pendingForkId: UUID?
    var pendingForkScope: String?
    var isArchived = false
    var followsRemote = false
    var isStreaming = false
    var remoteIsRunning = false
    var connectionKey: String { "\(id)|\(endpoint?.cacheId.uuidString ?? "")|\(path ?? "")" }
    var existsOnServer = false
    var title: String
    var path: String?

    init(id: UUID = UUID(), endpoint: Endpoint? = nil, path: String? = nil, title: String = "Untitled") {
        self.id = id
        self.endpoint = endpoint
        self.path = path
        self.title = title
    }
}

@Model
final class Window {
    var session: Session?

    init(session: Session? = nil) { self.session = session }
}

enum SessionActions {
    static var copiedHistory = false
    static func prepareFork(_ session: Session, scope: String) -> UUID {
        let id = session.pendingForkScope == scope ? session.pendingForkId ?? UUID() : UUID()
        restoreFork(session, id: id, scope: scope)
        return id
    }
    static func restoreFork(_ session: Session, id: UUID, scope: String) {
        session.pendingForkId = id
        session.pendingForkScope = scope
    }
    static func finishFork(_ session: Session, id: UUID) {
        if session.pendingForkId == id {
            session.pendingForkId = nil
            session.pendingForkScope = nil
        }
    }
    static func fork(
        _ source: Session, id: UUID, path: String, context: ModelContext, copyHistory: Bool = true
    ) -> Session {
        copiedHistory = copyHistory
        let session = Session(id: id, endpoint: source.endpoint, path: path, title: source.title)
        session.parentSessionId = source.id
        session.followsRemote = true
        context.insert(session)
        return session
    }
    static func setCodexThreadId(_ id: String, for session: Session) { session.codexThreadId = id }

    static func importThread(
        _ thread: SessionRemoteThread, id: UUID, endpoint: Endpoint, context: ModelContext
    ) -> Session {
        let session = Session(id: id, endpoint: endpoint, path: thread.cwd, title: thread.title)
        session.codexThreadId = thread.id
        session.followsRemote = true
        session.existsOnServer = true
        context.insert(session)
        return session
    }

    static func setArchived(_ session: Session, _ value: Bool) { session.isArchived = value }
    static func refreshRemoteTitle(_ thread: SessionRemoteThread, for session: Session) { session.title = thread.title }
}

enum WindowActions {
    static func activate(_ window: Window, among windows: [Window]) {}

    static func open(_ session: Session, among windows: [Window], context: ModelContext) {
        context.insert(Window(session: session))
    }
}

enum ChatActions {
    static var beforeImport: (() async -> Void)?
    static var importResult = true
    static var importedHistory: [String: Any]?
    static var discarded: [UUID] = []
    static func discardHistory(sessionId: UUID, context: ModelContext) { discarded.append(sessionId) }

    static func importHistory(
        _ history: [String: Any], session: Session, context: ModelContext
    ) async -> Bool {
        importedHistory = history
        if let beforeImport { await beforeImport() }
        return importResult
    }
}

struct SessionRemoteThread: Decodable, Identifiable {
    let id: String
    let cwd: String
    let preview: String
    let name: String?
    let updatedAt: Double
    let agentNickname: String?
    let agentPath: String?

    var title: String { name ?? preview }
}

struct SessionRemoteThreadDetail: Decodable {
    let thread: SessionRemoteThread
}

enum SessionSectionFilter {
    case all

    var query: [String: String] { [:] }
}

struct SessionRemoteThreadPage: Decodable {
    let data: [SessionRemoteThread]
    let nextCursor: String?
}

enum HTTPClient {
    static var getResponse: (Data, HTTPURLResponse)?
    static var postResponse: (Data, HTTPURLResponse)?
    static var beforeGet: (() async -> Void)?
    static var beforePost: ((String) async -> Void)?
    static var postPaths: [String] = []
    static var postBodies: [[String: Any]] = []
    static var getCalls = 0
    static var getQuery: [String: String] = [:]

    static func get(
        endpoint: Endpoint, path: String, timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        getCalls += 1
        if let beforeGet { await beforeGet() }
        return getResponse
    }

    static func get(
        endpoint: Endpoint, path: String, query: [String: String], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        getQuery = query
        return await get(endpoint: endpoint, path: path, timeout: timeout)
    }

    static func post(
        endpoint: Endpoint, path: String, body: [String: Any]
    ) async -> (Data, HTTPURLResponse)? {
        postPaths.append(path)
        if let beforePost { await beforePost(path) }
        return postResponse
    }

    static func post(
        endpoint: Endpoint, path: String, body: [String: Any], timeout: TimeInterval
    ) async -> (Data, HTTPURLResponse)? {
        postPaths.append(path)
        postBodies.append(body)
        if let beforePost { await beforePost(path) }
        if path.hasSuffix("/fork"), let response = postResponse,
            var object = try? JSONSerialization.jsonObject(with: response.0) as? [String: Any],
            object["sessionId"] == nil, let id = body["newSessionId"] as? String
        {
            object["sessionId"] = id
            return (try! JSONSerialization.data(withJSONObject: object), response.1)
        }
        return postResponse
    }
}
