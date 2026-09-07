import Foundation

extension SessionActions {
    @MainActor
    static func detachEndpoint(for session: Session) {
        session.endpoint = nil
        connectionChanged(for: session)
    }

    @MainActor
    static func connectionChanged(for session: Session) {
        session.hasGit = true
        session.isStreaming = false
        session.followsRemote = false
        session.remoteIsRunning = false
        session.needsAttention = false
        session.remoteHistoryETag = nil
        session.codexProjectId = nil
        session.codexProjectName = nil
    }

    @MainActor
    static func setEndpoint(_ endpoint: Endpoint, for session: Session, clearsPath: Bool = false) {
        let isSwitching = session.endpoint?.id != endpoint.id
        session.endpoint = endpoint
        if isSwitching {
            session.codexProjectId = nil
            session.codexProjectName = nil
        }
        if clearsPath && isSwitching {
            session.path = nil
            session.tab = .chat
            session.hasGit = true
        }
    }

    @MainActor
    static func setPath(_ path: String, for session: Session) {
        session.path = path
        session.codexProjectId = nil
        session.codexProjectName = nil
    }

    @MainActor
    static func setProject(
        _ project: SessionProject, root: SessionProjectRoot, endpoint: Endpoint, for session: Session
    ) {
        if !session.existsOnServer, !project.id.isEmpty, root.isAbsolute, project.roots.contains(root) {
            setEndpoint(endpoint, for: session)
            setPath(root.path, for: session)
            if session.provider != .codex { setProvider(.codex, for: session) }
            session.codexProjectId = project.id
            session.codexProjectName = project.displayName
        }
    }

    @MainActor
    static func setProvider(_ provider: ChatProvider, for session: Session) {
        if !session.existsOnServer && session.providerRaw != provider.rawValue {
            session.provider = provider
            session.codexProjectId = nil
            session.codexProjectName = nil
            session.model = nil
            session.effort = nil
            session.permissionMode = .standard
        }
    }
}
