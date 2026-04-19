import SwiftUI
import Network
import CloudeShared

extension AppDelegate {
    func handleMessage(_ message: ClientMessage, from connection: NWConnection) {
        switch message {
        case .chat(let text, let workingDirectory, let sessionId, let isNewSession, let imagesBase64, let filesBase64, let conversationId, let conversationName, let forkSession, let effort, let model):
            Log.info("Chat received: \(text.prefix(50))... (convId=\(conversationId?.prefix(8) ?? "nil"), images=\(imagesBase64?.count ?? 0), files=\(filesBase64?.count ?? 0), isNew=\(isNewSession), fork=\(forkSession), effort=\(effort ?? "nil"), model=\(model ?? "nil"))")
            if let wd = workingDirectory, !wd.isEmpty {
                ProjectRootService.projectDirectory = wd
            }
            let convId = conversationId ?? UUID().uuidString
            runnerManager.run(prompt: text, workingDirectory: workingDirectory, sessionId: sessionId, isNewSession: isNewSession, imagesBase64: imagesBase64, filesBase64: filesBase64, conversationId: convId, conversationName: conversationName, forkSession: forkSession, model: model, effort: effort)

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

        case .resumeFrom(let sessionId, let lastSeq):
            let result = runnerManager.replayBuffer.replayFrom(sessionId: sessionId, lastSeq: lastSeq)
            Log.info("resumeFrom sessionId=\(sessionId.prefix(8)) lastSeq=\(lastSeq) events=\(result.events.count) historyOnly=\(result.historyOnly)")
            server.sendMessage(.resumeFromResponse(sessionId: sessionId, events: result.events, historyOnly: result.historyOnly), to: connection)

        case .gitStatus(let path):
            handleGitStatus(path, connection: connection)

        case .gitDiff(let path, let file, let staged):
            handleGitDiff(path, file: file, staged: staged, connection: connection)

        case .gitCommit(let path, let message, let files):
            handleGitCommit(path, message: message, files: files, connection: connection)

        case .gitLog(let path, let count):
            handleGitLog(path, count: count, connection: connection)

        case .transcribe(let audioBase64):
            handleTranscribe(audioBase64, connection: connection)

        case .searchFiles(let query, let workingDirectory):
            Log.info("Searching files for '\(query)' in \(workingDirectory)")
            let files = FileSearchService.search(query: query, in: workingDirectory)
            server.sendMessage(.fileSearchResults(files: files), to: connection)

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

        case .suggestName(let text, let context, let conversationId):
            Log.info("Name suggestion request for \(conversationId.prefix(8))")
            autocompleteService.suggestName(text: text, context: context) { [weak self] name, symbol in
                Log.info("Name suggestion: \"\(name)\" symbol=\(symbol ?? "nil")")
                self?.server.broadcast(.nameSuggestion(name: name, symbol: symbol, conversationId: conversationId))
            }

        case .ping(let sentAt):
            server.sendMessage(.pong(sentAt: sentAt, serverAt: Date().timeIntervalSince1970), to: connection)
        }
    }
}
