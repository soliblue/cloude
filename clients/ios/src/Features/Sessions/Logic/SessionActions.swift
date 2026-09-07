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
        session.providerRaw = endpoint?.supportsCodex == true ? ChatProvider.codex.rawValue : nil
        context.insert(session)
        return session
    }

    @MainActor
    static func importThread(
        _ thread: SessionRemoteThread, id: UUID, endpoint: Endpoint, context: ModelContext
    ) -> Session {
        let session = Session(id: id, endpoint: endpoint, path: thread.cwd, title: thread.title, symbol: "terminal")
        session.provider = .codex
        session.codexThreadId = thread.id
        session.followsRemote = true
        session.existsOnServer = true
        context.insert(session)
        return session
    }

    @MainActor
    static func setGoal(_ goal: ChatGoal?, for session: Session) {
        session.goalData = goal.flatMap { try? JSONEncoder().encode($0) }
    }

    @MainActor
    static func setRemoteFollowing(_ value: Bool, for session: Session) {
        session.followsRemote = value
        if !value { session.remoteIsRunning = false }
    }

    @MainActor
    static func setRemoteRunning(_ value: Bool, for session: Session) {
        session.remoteIsRunning = value
    }

    @MainActor
    static func setRemoteTurnStatus(_ value: String?, for session: Session) {
        session.remoteTurnStatus = value
    }

    @MainActor
    static func refreshRemoteTitle(_ thread: SessionRemoteThread, for session: Session) {
        if !session.hasCustomTitle, thread.title != "Untitled Codex chat" {
            session.title = thread.title
        }
    }

    @MainActor
    static func setRemoteHistoryETag(_ value: String?, for session: Session) {
        session.remoteHistoryETag = value
    }

    @MainActor
    static func setCodexThreadId(_ id: String, for session: Session) {
        session.codexThreadId = id
    }

    @MainActor
    static func prepareFork(_ session: Session, scope: String) -> UUID {
        let id = session.pendingForkScope == scope ? session.pendingForkId ?? UUID() : UUID()
        restoreFork(session, id: id, scope: scope)
        return id
    }

    @MainActor
    static func restoreFork(_ session: Session, id: UUID, scope: String) {
        session.pendingForkId = id
        session.pendingForkScope = scope
    }

    @MainActor
    static func finishFork(_ session: Session, id: UUID) {
        if session.pendingForkId == id {
            session.pendingForkId = nil
            session.pendingForkScope = nil
        }
    }

    @MainActor
    static func fork(
        _ source: Session, id: UUID, path: String, context: ModelContext, copyHistory: Bool = true
    ) -> Session {
        let session = Session(
            id: id, endpoint: source.endpoint, path: path, title: source.title + " · side chat",
            symbol: "arrow.triangle.branch")
        session.provider = source.provider
        session.model = source.model
        session.effort = source.effort
        session.permissionMode = source.permissionMode
        session.parentSessionId = source.id
        session.followsRemote = true
        session.existsOnServer = true
        context.insert(session)
        if copyHistory { ChatActions.copyHistory(from: source.id, to: session.id, context: context) }
        return session
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
        if let effort = session.effort,
            !ChatModelCatalog.shared.efforts(sessionId: session.id, provider: session.provider, model: model).contains(
                effort)
        {
            session.effort = nil
        }
    }

    @MainActor
    static func setModel(_ model: ChatModel?, for sessionId: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        if let session = try? context.fetch(descriptor).first {
            setModel(model, for: session)
        }
    }

    @MainActor
    static func setEffort(_ effort: ChatEffort?, for session: Session) {
        session.effort = effort
    }

    @MainActor
    static func setEffort(_ effort: ChatEffort?, for sessionId: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        if let session = try? context.fetch(descriptor).first {
            session.effort = effort
        }
    }

    @MainActor
    static func setPermissionMode(
        _ mode: ChatPermissionMode, for sessionId: UUID, context: ModelContext
    ) {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        if let session = try? context.fetch(descriptor).first {
            session.permissionMode = mode
        }
    }

    @MainActor
    static func setContextUsage(
        tokens: Int?, window: Int?, for sessionId: UUID, context: ModelContext
    ) {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == sessionId }
        )
        if let session = try? context.fetch(descriptor).first {
            if let tokens { session.contextTokens = tokens }
            if let window { session.contextWindow = window }
        }
    }

    @MainActor
    static func setUnread(_ value: Bool, for session: Session) {
        session.hasUnread = value
    }

    @MainActor
    static func setNeedsAttention(_ value: Bool, for session: Session) {
        session.needsAttention = value
    }

    @MainActor
    static func setArchived(_ session: Session, _ archived: Bool) {
        session.isArchived = archived
    }

    @MainActor
    static func rename(_ session: Session, title: String) {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            session.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            session.hasCustomTitle = true
        }
    }

    @MainActor
    static func setPinned(_ session: Session, _ pinned: Bool) {
        session.isPinned = pinned
    }

    @MainActor
    static func markOpened(_ session: Session, markRead: Bool = true) {
        session.lastOpenedAt = .now
        if markRead { session.hasUnread = false }
    }

    @MainActor
    static func setStreaming(_ isStreaming: Bool, for session: Session) {
        session.isStreaming = isStreaming
    }

    @MainActor
    static func setLastSeq(_ seq: Int, for session: Session) {
        session.lastSeq = seq
    }

    @MainActor
    static func setHasGit(_ hasGit: Bool, for session: Session) {
        if session.hasGit != hasGit { session.hasGit = hasGit }
    }

    @MainActor
    static func setTitleAndSymbol(_ title: String, _ symbol: String, for session: Session) {
        if !session.hasCustomTitle {
            session.title = title
            session.symbol = symbol
        }
    }

    @MainActor
    @discardableResult
    static func deleteIfEmpty(_ session: Session, context: ModelContext) -> Task<Void, Never> {
        let sessionId = session.id
        return Task { @MainActor in
            let loaded = await ChatDraftService.load(sessionId)
            let descriptor = FetchDescriptor<ChatMessage>(
                predicate: #Predicate<ChatMessage> { $0.sessionId == sessionId }
            )
            let count = (try? context.fetchCount(descriptor)) ?? 0
            let windows = try? context.fetch(FetchDescriptor<Window>())
            if loaded && count == 0 && ChatDraftStore.snapshot(for: sessionId).isEmpty,
                session.modelContext != nil, let windows,
                !windows.contains(where: { $0.session?.id == sessionId })
            {
                GitActions.clear(sessionId: sessionId, context: context)
                context.delete(session)
                ChatDraftService.clear(sessionId)
            }
        }
    }
}
