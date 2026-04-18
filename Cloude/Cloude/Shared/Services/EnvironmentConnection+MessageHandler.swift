import Foundation
import Combine
import CloudeShared
import OSLog

extension EnvironmentConnection {
    func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(ServerMessage.self, from: data),
              let mgr = manager else { return }

        switch message {
        case .output(let text, let conversationId):       handleOutput(mgr, text: text, conversationId: conversationId)
        case .status(let state, let conversationId):      handleStatus(mgr, state: state, conversationId: conversationId)
        case .authRequired:
            AppLogger.connectionInfo("auth required envId=\(environmentId.uuidString)")
            authenticate()
        case .authResult(let success, let msg):
            AppLogger.connectionInfo("auth result envId=\(environmentId.uuidString) success=\(success) message=\(msg ?? "")")
            AppLogger.endInterval("environment.auth", key: environmentId.uuidString, details: "success=\(success)")
            handleAuthResult(mgr, success: success, errorMessage: msg)
        case .error(let msg):
            AppLogger.connectionError("server error envId=\(environmentId.uuidString) message=\(msg)")
            if let path = gitStatusInFlightPath {
                gitStatusTimeoutTask?.cancel()
                gitStatusInFlightPath = nil
                mgr.events.send(.gitStatusError(path: path, message: msg, environmentId: environmentId))
                sendNextGitStatusIfNeeded()
            }
            handleError(mgr, msg)
        case .toolCall(let n, let i, let t, let p, let c, let pos, let ei): handleToolCall(mgr, name: n, input: i, toolId: t, parentToolId: p, conversationId: c, textPosition: pos, editInfo: ei)
        case .toolResult(let id, let sum, let out, let c):  handleToolResult(mgr, toolId: id, summary: sum, output: out, conversationId: c)
        case .runStats(let ms, let cost, let m, let c):    handleRunStats(mgr, durationMs: ms, costUsd: cost, model: m, conversationId: c)
        case .missedResponse(let sid, let t, _, let tc, let durationMs, let costUsd, let model):  handleMissedResponse(mgr, sessionId: sid, text: t, storedToolCalls: tc, durationMs: durationMs, costUsd: costUsd, model: model)
        case .noMissedResponse(let sid):                  handleNoMissedResponse(mgr, sessionId: sid)
        case .sessionId(let id, let c):                   handleSessionId(mgr, id, conversationId: c)
        case .messageUUID(let uuid, let c):               handleMessageUUID(mgr, uuid, conversationId: c)
        case .directoryListing(let path, let entries):    mgr.events.send(.directoryListing(path: path, entries: entries, environmentId: environmentId))
        case .fileContent(let p, let d, let m, let s, let t): handleFileContent(mgr, path: p, data: d, mimeType: m, size: s, truncated: t)
        case .fileChunk(let p, let ci, let tc, let d, let m, let s): handleFileChunk(mgr, path: p, chunkIndex: ci, totalChunks: tc, data: d, mimeType: m, size: s)
        case .fileThumbnail(let p, let d, let fs):        mgr.events.send(.fileThumbnail(path: p, data: d, fullSize: fs))
        case .fileSearchResults(let files, let query):    mgr.events.send(.fileSearchResults(files: files, query: query))
        case .gitStatusResult(let status):                handleGitStatusResult(mgr, status)
        case .gitDiffResult(let path, let diff):          mgr.events.send(.gitDiff(path: path, diff: diff))
        case .gitLogResult(let path, let commits):       mgr.events.send(.gitLog(path: path, commits: commits, environmentId: environmentId))
        case .transcription(let text):                    handleTranscription(mgr, text)
        case .whisperReady(let ready):                    isWhisperReady = ready
        case .skills(let s):                              handleSkills(mgr, s)
        case .defaultWorkingDirectory(let path):
            defaultWorkingDirectory = path
            mgr.events.send(.defaultWorkingDirectory(path: path, environmentId: environmentId))
        case .processList(let procs):                     processes = procs
        case .historySync(let sid, let msgs):             mgr.events.send(.historySync(sessionId: sid, messages: msgs))
        case .historySyncError(let sid, let err):          mgr.events.send(.historySyncError(sessionId: sid, error: err))
        case .remoteSessionList:                          break
        case .nameSuggestion(let name, let sym, let c):   handleNameSuggestion(mgr, name: name, symbol: sym, conversationId: c)
        case .pong(let sentAt, _):                        latencyMs = (Date().timeIntervalSince1970 - sentAt) * 1000
        case .fileChange, .image, .gitCommitResult:       break
        }
    }

    func handleDisconnect() {
        guard let mgr = manager else { return }
        AppLogger.connectionInfo("handleDisconnect envId=\(environmentId.uuidString)")
        for (convId, output) in mgr.runningOutputs(for: environmentId) {
            output.flushBuffer()
            output.completeExecutingTools()
            let snapshot = ConversationOutput()
            snapshot.text = output.text
            snapshot.fullText = output.fullText
            snapshot.toolCalls = output.toolCalls
            snapshot.newSessionId = output.newSessionId
            snapshot.liveMessageId = output.liveMessageId
            mgr.events.send(.disconnect(conversationId: convId, output: snapshot))
            output.reset()
            output.isRunning = false
        }
        isConnected = false
        isAuthenticated = false
        isWhisperReady = false
        isTranscribing = false
        agentState = .idle
        gitStatusQueue.removeAll()
        gitStatusInFlightPath = nil
        mgr.endBackgroundStreaming()
        mgr.objectWillChange.send()
    }

    func targetConversationId(from conversationId: String?) -> UUID? {
        conversationId.flatMap { UUID(uuidString: $0) }
    }

    func sendNextGitStatusIfNeeded() {
        guard isAuthenticated, gitStatusInFlightPath == nil, !gitStatusQueue.isEmpty else { return }
        let next = gitStatusQueue.removeFirst()
        gitStatusInFlightPath = next
        send(.gitStatus(path: next))

        gitStatusTimeoutTask?.cancel()
        gitStatusTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self, self.gitStatusInFlightPath == next else { return }
            self.gitStatusInFlightPath = nil
            self.sendNextGitStatusIfNeeded()
        }
    }
}
