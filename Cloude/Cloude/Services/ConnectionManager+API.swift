import Foundation
import CloudeShared

extension ConnectionManager {
    func connectionForSend(environmentId: UUID? = nil, conversationId: UUID? = nil) -> EnvironmentConnection? {
        if let envId = environmentId { return connections[envId] }
        if let convId = conversationId, let conn = connectionForConversation(convId) { return conn }
        return anyAuthenticatedConnection()
    }

    func sendChat(_ message: String, workingDirectory: String? = nil, sessionId: String? = nil, isNewSession: Bool = true, conversationId: UUID? = nil, imagesBase64: [String]? = nil, filesBase64: [AttachedFilePayload]? = nil, conversationName: String? = nil, conversationSymbol: String? = nil, forkSession: Bool = false, effort: String? = nil, model: String? = nil, environmentId: UUID? = nil) {
        guard let conn = connectionForSend(environmentId: environmentId, conversationId: conversationId) else { return }
        if let convId = conversationId {
            conn.runningConversationId = convId
            registerConversation(convId, environmentId: conn.environmentId)
            output(for: convId).reset()
            output(for: convId).isRunning = true
            LiveActivityManager.shared.startActivity(
                conversationId: convId,
                conversationName: conversationName ?? "Chat",
                conversationSymbol: conversationSymbol
            )
        }
        let effectiveWorkingDir = workingDirectory ?? conn.defaultWorkingDirectory
        conn.send(.chat(message: message, workingDirectory: effectiveWorkingDir, sessionId: sessionId, isNewSession: isNewSession, imagesBase64: imagesBase64, filesBase64: filesBase64, conversationId: conversationId?.uuidString, conversationName: conversationName, forkSession: forkSession, effort: effort, model: model))
    }

    func abort(conversationId: UUID? = nil) {
        let conn = conversationId.flatMap { connectionForConversation($0) } ?? anyAuthenticatedConnection()
        conn?.send(.abort(conversationId: conversationId?.uuidString))
    }

    func searchFiles(query: String, workingDirectory: String, environmentId: UUID? = nil) {
        connectionForSend(environmentId: environmentId)?.send(.searchFiles(query: query, workingDirectory: workingDirectory))
    }

    func getPlans(workingDirectory: String, environmentId: UUID? = nil) {
        connectionForSend(environmentId: environmentId)?.send(.getPlans(workingDirectory: workingDirectory))
    }

    func deletePlan(stage: String, filename: String, workingDirectory: String, environmentId: UUID? = nil) {
        connectionForSend(environmentId: environmentId)?.send(.deletePlan(stage: stage, filename: filename, workingDirectory: workingDirectory))
    }

    func getUsageStats(environmentId: UUID? = nil) { connectionForSend(environmentId: environmentId)?.send(.getUsageStats) }
    func listDirectory(path: String, environmentId: UUID? = nil) { connectionForSend(environmentId: environmentId)?.send(.listDirectory(path: path)) }
    func getFile(path: String, environmentId: UUID? = nil) { connectionForSend(environmentId: environmentId)?.send(.getFile(path: path)) }
    func getFileFullQuality(path: String, environmentId: UUID? = nil) { connectionForSend(environmentId: environmentId)?.send(.getFileFullQuality(path: path)) }

    func requestMissedResponse(sessionId: String, environmentId: UUID? = nil) {
        connectionForSend(environmentId: environmentId)?.send(.requestMissedResponse(sessionId: sessionId))
    }

    func gitStatus(path: String, environmentId: UUID? = nil) {
        if let conn = connectionForSend(environmentId: environmentId) {
            conn.gitStatusQueue.append(path)
            conn.sendNextGitStatusIfNeeded()
        }
    }

    func gitDiff(path: String, file: String? = nil, staged: Bool = false, environmentId: UUID? = nil) { connectionForSend(environmentId: environmentId)?.send(.gitDiff(path: path, file: file, staged: staged)) }
    func gitCommit(path: String, message: String, files: [String], environmentId: UUID? = nil) { connectionForSend(environmentId: environmentId)?.send(.gitCommit(path: path, message: message, files: files)) }
    func getProcesses(environmentId: UUID? = nil) { connectionForSend(environmentId: environmentId)?.send(.getProcesses) }
    func killProcess(pid: Int32, environmentId: UUID? = nil) { connectionForSend(environmentId: environmentId)?.send(.killProcess(pid: pid)) }
    func killAllProcesses(environmentId: UUID? = nil) { connectionForSend(environmentId: environmentId)?.send(.killAllProcesses) }
    func syncHistory(sessionId: String, workingDirectory: String, environmentId: UUID? = nil) { connectionForSend(environmentId: environmentId)?.send(.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory)) }
    func listRemoteSessions(workingDirectory: String, environmentId: UUID? = nil) { connectionForSend(environmentId: environmentId)?.send(.listRemoteSessions(workingDirectory: workingDirectory)) }

    func transcribe(audioBase64: String, environmentId: UUID? = nil) {
        if let conn = connectionForSend(environmentId: environmentId) {
            conn.isTranscribing = true
            conn.send(.transcribe(audioBase64: audioBase64))
        }
    }

    func requestNameSuggestion(text: String, context: [String], conversationId: UUID) {
        connectionForSend(conversationId: conversationId)?.send(.suggestName(text: text, context: context, conversationId: conversationId.uuidString))
    }

    func send(_ message: ClientMessage, environmentId: UUID? = nil) {
        connectionForSend(environmentId: environmentId)?.send(message)
    }
}
