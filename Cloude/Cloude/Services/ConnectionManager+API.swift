import Foundation
import Combine
import CloudeShared

extension ConnectionManager {
    private func ensureAuthenticated() {
        if !isAuthenticated { reconnectIfNeeded() }
    }

    func searchFiles(query: String, workingDirectory: String) {
        ensureAuthenticated()
        send(.searchFiles(query: query, workingDirectory: workingDirectory))
    }

    func sendChat(_ message: String, workingDirectory: String? = nil, sessionId: String? = nil, isNewSession: Bool = true, conversationId: UUID? = nil, imagesBase64: [String]? = nil, filesBase64: [AttachedFilePayload]? = nil, conversationName: String? = nil, conversationSymbol: String? = nil, forkSession: Bool = false, effort: String? = nil, model: String? = nil) {
        ensureAuthenticated()
        if let convId = conversationId {
            runningConversationId = convId
            output(for: convId).reset()
            output(for: convId).isRunning = true
            LiveActivityManager.shared.startActivity(
                conversationId: convId,
                conversationName: conversationName ?? "Chat",
                conversationSymbol: conversationSymbol
            )
        }
        let effectiveWorkingDir = workingDirectory ?? defaultWorkingDirectory
        send(.chat(message: message, workingDirectory: effectiveWorkingDir, sessionId: sessionId, isNewSession: isNewSession, imagesBase64: imagesBase64, filesBase64: filesBase64, conversationId: conversationId?.uuidString, conversationName: conversationName, forkSession: forkSession, effort: effort, model: model))
    }

    func abort(conversationId: UUID? = nil) {
        send(.abort(conversationId: conversationId?.uuidString))
    }

    func getPlans(workingDirectory: String) { ensureAuthenticated(); send(.getPlans(workingDirectory: workingDirectory)) }
    func deletePlan(stage: String, filename: String, workingDirectory: String) { ensureAuthenticated(); send(.deletePlan(stage: stage, filename: filename, workingDirectory: workingDirectory)) }

    func getUsageStats()                                           { ensureAuthenticated(); send(.getUsageStats) }
    func getScheduledTasks()                                        { ensureAuthenticated(); send(.getScheduledTasks) }
    func toggleScheduledTask(taskId: String, isActive: Bool)        { ensureAuthenticated(); send(.toggleScheduledTask(taskId: taskId, isActive: isActive)) }
    func deleteScheduledTask(taskId: String)                        { ensureAuthenticated(); send(.deleteScheduledTask(taskId: taskId)) }
    func listDirectory(path: String)                              { ensureAuthenticated(); send(.listDirectory(path: path)) }
    func getFile(path: String)                                    { ensureAuthenticated(); send(.getFile(path: path)) }
    func getFileFullQuality(path: String)                         { ensureAuthenticated(); send(.getFileFullQuality(path: path)) }
    func requestMissedResponse(sessionId: String)                 { ensureAuthenticated(); send(.requestMissedResponse(sessionId: sessionId)) }
    func gitStatus(path: String) {
        ensureAuthenticated()
        gitStatusQueue.append(path)
        sendNextGitStatusIfNeeded()
    }

    // Internal because git-status results don't include the path; message handling needs to advance the queue.
    func sendNextGitStatusIfNeeded() {
        guard gitStatusInFlightPath == nil else { return }
        guard !gitStatusQueue.isEmpty else { return }
        let next = gitStatusQueue.removeFirst()
        gitStatusInFlightPath = next
        send(.gitStatus(path: next))
    }
    func gitDiff(path: String, file: String? = nil)               { ensureAuthenticated(); send(.gitDiff(path: path, file: file)) }
    func gitCommit(path: String, message: String, files: [String]) { ensureAuthenticated(); send(.gitCommit(path: path, message: message, files: files)) }
    func getProcesses()                                           { ensureAuthenticated(); send(.getProcesses) }
    func killProcess(pid: Int32)                                  { ensureAuthenticated(); send(.killProcess(pid: pid)) }
    func killAllProcesses()                                       { ensureAuthenticated(); send(.killAllProcesses) }
    func syncHistory(sessionId: String, workingDirectory: String) { ensureAuthenticated(); send(.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory)) }
    func listRemoteSessions(workingDirectory: String)             { ensureAuthenticated(); send(.listRemoteSessions(workingDirectory: workingDirectory)) }

    func transcribe(audioBase64: String) {
        ensureAuthenticated()
        isTranscribing = true
        send(.transcribe(audioBase64: audioBase64))
    }

    func synthesize(text: String, messageId: String, voice: String? = nil) {
        ensureAuthenticated()
        send(.synthesize(text: text, messageId: messageId, voice: voice))
    }

    func requestSuggestions(context: [String], workingDirectory: String?, conversationId: UUID?) {
        ensureAuthenticated()
        send(.requestSuggestions(context: context, workingDirectory: workingDirectory, conversationId: conversationId?.uuidString))
    }

    func requestNameSuggestion(text: String, context: [String], conversationId: UUID) {
        ensureAuthenticated()
        send(.suggestName(text: text, context: context, conversationId: conversationId.uuidString))
    }
}
