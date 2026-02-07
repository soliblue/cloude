import SwiftUI
import Network
import CloudeShared

extension AppDelegate {
    func handleMessage(_ message: ClientMessage, from connection: NWConnection) {
        switch message {
        case .chat(let text, let workingDirectory, let sessionId, let isNewSession, let imagesBase64, let conversationId, let conversationName, let forkSession, let effort, let model):
            Log.info("Chat received: \(text.prefix(50))... (convId=\(conversationId?.prefix(8) ?? "nil"), images=\(imagesBase64?.count ?? 0), isNew=\(isNewSession), fork=\(forkSession), effort=\(effort ?? "nil"), model=\(model ?? "nil"))")
            if let wd = workingDirectory, !wd.isEmpty {
                HeartbeatService.shared.projectDirectory = wd
            }
            let convId = conversationId ?? UUID().uuidString
            runnerManager.run(prompt: text, workingDirectory: workingDirectory, sessionId: sessionId, isNewSession: isNewSession, imagesBase64: imagesBase64, conversationId: convId, conversationName: conversationName, forkSession: forkSession, model: model, effort: effort)

        case .abort(let conversationId):
            if let convId = conversationId {
                Log.info("Abort requested for conversation \(convId.prefix(8))")
                runnerManager.abort(conversationId: convId)
            } else {
                Log.info("Abort all requested")
                runnerManager.abortAll()
            }

        case .listDirectory(let path):
            handleListDirectory(path, connection: connection)

        case .getFile(let path):
            handleGetFile(path, connection: connection)

        case .getFileFullQuality(let path):
            handleGetFile(path, connection: connection, fullQuality: true)

        case .auth:
            break

        case .requestMissedResponse(let sessionId):
            if let stored = ResponseStore.retrieve(sessionId: sessionId) {
                server.sendMessage(.missedResponse(sessionId: sessionId, text: stored.text, completedAt: stored.completedAt, toolCalls: stored.toolCalls), to: connection)
                ResponseStore.clear(sessionId: sessionId)
            } else {
                server.sendMessage(.noMissedResponse(sessionId: sessionId), to: connection)
            }

        case .gitStatus(let path):
            handleGitStatus(path, connection: connection)

        case .gitDiff(let path, let file):
            handleGitDiff(path, file: file, connection: connection)

        case .gitCommit(let path, let message, let files):
            handleGitCommit(path, message: message, files: files, connection: connection)

        case .transcribe(let audioBase64):
            handleTranscribe(audioBase64, connection: connection)

        case .setHeartbeatInterval(let minutes):
            Log.info("setHeartbeatInterval: \(String(describing: minutes))")
            HeartbeatService.shared.setInterval(minutes)
            let config = HeartbeatService.shared.getConfig()
            Log.info("Broadcasting config: interval=\(String(describing: config.intervalMinutes)), unread=\(config.unreadCount)")
            server.broadcast(.heartbeatConfig(intervalMinutes: config.intervalMinutes, unreadCount: config.unreadCount))

        case .getHeartbeatConfig:
            let config = HeartbeatService.shared.getConfig()
            server.sendMessage(.heartbeatConfig(intervalMinutes: config.intervalMinutes, unreadCount: config.unreadCount), to: connection)

        case .markHeartbeatRead:
            HeartbeatService.shared.markRead()
            let config = HeartbeatService.shared.getConfig()
            server.broadcast(.heartbeatConfig(intervalMinutes: config.intervalMinutes, unreadCount: config.unreadCount))

        case .triggerHeartbeat:
            Log.info("Received triggerHeartbeat request")
            HeartbeatService.shared.triggerNow()

        case .getMemories:
            Log.info("Received getMemories request")
            let sections = MemoryService.parseMemories()
            server.sendMessage(.memories(sections: sections), to: connection)

        case .getProcesses:
            let procs = runnerManager.getProcessInfo()
            server.sendMessage(.processList(processes: procs), to: connection)

        case .killProcess(let pid):
            Log.info("Killing process \(pid)")
            _ = ProcessMonitor.killProcess(pid)
            let procs = runnerManager.getProcessInfo()
            server.broadcast(.processList(processes: procs))

        case .killAllProcesses:
            Log.info("Killing all Claude processes")
            _ = ProcessMonitor.killAllClaudeProcesses()
            server.broadcast(.processList(processes: []))

        case .searchFiles(let query, let workingDirectory):
            Log.info("Searching files for '\(query)' in \(workingDirectory)")
            let files = FileSearchService.search(query: query, in: workingDirectory)
            server.sendMessage(.fileSearchResults(files: files, query: query), to: connection)

        case .syncHistory(let sessionId, let workingDirectory):
            Log.info("Syncing history for session \(sessionId.prefix(8)) in \(workingDirectory)")
            let result = HistoryService.getHistory(sessionId: sessionId, workingDirectory: workingDirectory)
            switch result {
            case .success(let messages):
                Log.info("Found \(messages.count) messages")
                server.sendMessage(.historySync(sessionId: sessionId, messages: messages), to: connection)
            case .failure(let error):
                let errorMsg: String
                switch error {
                case .fileNotFound(let path): errorMsg = "Session file not found: \(path)"
                case .readFailed(let msg): errorMsg = "Read failed: \(msg)"
                }
                Log.error("History sync failed: \(errorMsg)")
                server.sendMessage(.historySyncError(sessionId: sessionId, error: errorMsg), to: connection)
            }

        case .listRemoteSessions(let workingDirectory):
            Log.info("Listing remote sessions for \(workingDirectory)")
            let sessions = HistoryService.listSessions(workingDirectory: workingDirectory)
            Log.info("Found \(sessions.count) sessions")
            server.sendMessage(.remoteSessionList(sessions: sessions), to: connection)

        case .autocomplete(let text, let context, let workingDirectory):
            Log.info("Autocomplete request: \"\(text.prefix(30))\"")
            autocompleteService.complete(text: text, context: context, workingDirectory: workingDirectory) { [weak self] result in
                if let suggestion = result {
                    Log.info("Autocomplete result: \"\(suggestion.prefix(40))\"")
                    self?.server.sendMessage(.autocompleteResult(text: suggestion, requestText: text), to: connection)
                }
            }

        case .suggestName(let text, let context, let conversationId):
            Log.info("Name suggestion request for \(conversationId.prefix(8))")
            autocompleteService.suggestName(text: text, context: context) { [weak self] name, symbol in
                Log.info("Name suggestion: \"\(name)\" symbol=\(symbol ?? "nil")")
                self?.server.broadcast(.nameSuggestion(name: name, symbol: symbol, conversationId: conversationId))
            }
        }
    }
}
