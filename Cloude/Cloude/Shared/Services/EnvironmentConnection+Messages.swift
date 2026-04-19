import Combine
import Foundation
import CloudeShared

extension EnvironmentConnection {
    func handleMessage(_ text: String) {
        if let data = text.data(using: .utf8),
           let message = try? JSONDecoder().decode(ServerMessage.self, from: data),
           let mgr = manager {
            switch message {
            case .output(let text, let conversationId, let seq): handleOutput(mgr, text: text, conversationId: conversationId, seq: seq)
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
                handleError(msg)
            case .toolCall(let n, let i, let t, let p, let c, let pos, let ei, let seq): handleToolCall(mgr, name: n, input: i, toolId: t, parentToolId: p, conversationId: c, textPosition: pos, editInfo: ei, seq: seq)
            case .toolResult(let id, _, let out, let c, let seq):  handleToolResult(mgr, toolId: id, output: out, conversationId: c, seq: seq)
            case .runStats(let ms, let cost, let m, let c, let seq):    handleRunStats(mgr, durationMs: ms, costUsd: cost, model: m, conversationId: c, seq: seq)
            case .resumeFromResponse(let sid, let events, let historyOnly): handleResumeFromResponse(mgr, sessionId: sid, events: events, historyOnly: historyOnly)
            case .sessionId(let id, let c):                   handleSessionId(mgr, id, conversationId: c)
            case .messageUUID(let uuid, let c):               handleMessageUUID(mgr, uuid, conversationId: c)
            case .directoryListing(let path, let entries):    files.handleDirectoryListing(path: path, entries: entries)
            case .fileContent(let p, let d, let m, let s, let t): files.handleFileContent(path: p, data: d, mimeType: m, size: s, truncated: t)
            case .fileChunk(let p, let ci, let tc, let d, let m, let s): files.handleFileChunk(path: p, chunkIndex: ci, totalChunks: tc, data: d, mimeType: m, size: s)
            case .fileThumbnail(let p, let d, let fs):        files.handleFileThumbnail(path: p, data: d, fullSize: fs)
            case .fileSearchResults(let files):               self.files.handleSearchResults(files)
            case .gitStatusResult(let status):                git.handleStatusResult(status)
            case .gitDiffResult(let path, let diff):          git.handleDiffResult(path: path, diff: diff)
            case .gitLogResult(let path, let commits):        git.handleLogResult(path: path, commits: commits)
            case .transcription(let text):                    handleTranscription(mgr, text)
            case .whisperReady(let ready):                    isWhisperReady = ready
            case .skills(let s):                              handleSkills(mgr, s)
            case .defaultWorkingDirectory(let path):
                defaultWorkingDirectory = path
                mgr.events.send(.defaultWorkingDirectory(path: path, environmentId: environmentId))
            case .historySync(let sid, let msgs):             mgr.events.send(.historySync(sessionId: sid, messages: msgs))
            case .historySyncError(let sid, let err):          mgr.events.send(.historySyncError(sessionId: sid, error: err))
            case .nameSuggestion(let name, let sym, let c):   handleNameSuggestion(mgr, name: name, symbol: sym, conversationId: c)
            case .pong(let sentAt, _):                        latencyMs = (Date().timeIntervalSince1970 - sentAt) * 1000
            case .gitCommitResult:                            break
            }
        }
    }
}
