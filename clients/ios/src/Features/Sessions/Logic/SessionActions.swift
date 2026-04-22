import Foundation
import SwiftData

enum SessionActions {
    @MainActor
    static func add(
        into context: ModelContext,
        endpoint: Endpoint? = nil,
        path: String? = nil
    ) -> Session {
        let session = Session(
            endpoint: endpoint,
            path: path,
            title: SessionRandom.name(),
            symbol: SessionRandom.symbol()
        )
        context.insert(session)
        return session
    }

    @MainActor
    static func setEndpoint(_ endpoint: Endpoint, for session: Session) {
        session.endpoint = endpoint
    }

    @MainActor
    static func setPath(_ path: String, for session: Session) {
        session.path = path
    }

    @MainActor
    static func markExistsOnServer(_ session: Session) {
        session.existsOnServer = true
    }

    @MainActor
    static func setTab(_ tab: SessionTab, for session: Session) {
        session.tab = tab
    }

    @MainActor
    static func setModel(_ model: ChatModel?, for session: Session) {
        session.model = model
    }

    @MainActor
    static func setEffort(_ effort: ChatEffort?, for session: Session) {
        session.effort = effort
    }

    @MainActor
    static func markOpened(_ session: Session) {
        session.lastOpenedAt = .now
    }

    @MainActor
    static func setStreaming(_ isStreaming: Bool, for session: Session) {
        session.isStreaming = isStreaming
    }

    @MainActor
    static func setHasGit(_ hasGit: Bool, for session: Session) {
        if session.hasGit != hasGit { session.hasGit = hasGit }
    }

    @MainActor
    static func setTitleAndSymbol(_ title: String, _ symbol: String, for session: Session) {
        session.title = title
        session.symbol = symbol
    }

    @MainActor
    static func delete(_ session: Session, context: ModelContext) {
        context.delete(session)
    }

    @MainActor
    static func deleteIfEmpty(_ session: Session, context: ModelContext) {
        let sessionId = session.id
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate<ChatMessage> { $0.sessionId == sessionId }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0
        if count == 0 {
            context.delete(session)
        }
    }
}
