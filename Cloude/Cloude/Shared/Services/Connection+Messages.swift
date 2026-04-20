import Combine
import Foundation
import CloudeShared

extension Connection {
    func handleMessage(_ text: String) {
        if let data = text.data(using: .utf8),
           let message = try? JSONDecoder().decode(ServerMessage.self, from: data),
           let store = connectionStore {
            switch message {
            case .output(let text, let conversationId, let seq): conversationRuntime.handleOutput(text: text, conversationId: conversationId, seq: seq)
            case .status(let state, let conversationId):      conversationRuntime.handleStatus(state: state, conversationId: conversationId)
            case .authRequired:
                AppLogger.connectionInfo("auth required envId=\(environmentId.uuidString)")
                authenticate()
            case .authResult(let success, let msg):
                AppLogger.connectionInfo("auth result envId=\(environmentId.uuidString) success=\(success) message=\(msg ?? "")")
                AppLogger.endInterval("environment.auth", key: environmentId.uuidString, details: "success=\(success)")
                handleAuthResult(store, success: success, errorMessage: msg)
            case .error(let msg):
                AppLogger.connectionError("server error envId=\(environmentId.uuidString) message=\(msg)")
                handleError(msg)
            case .toolCall(let n, let i, let t, let p, let c, let pos, let ei, let seq): conversationRuntime.handleToolCall(name: n, input: i, toolId: t, parentToolId: p, conversationId: c, textPosition: pos, editInfo: ei, seq: seq)
            case .toolResult(let id, _, let out, let c, let seq):  conversationRuntime.handleToolResult(toolId: id, resultOutput: out, conversationId: c, seq: seq)
            case .runStats(let ms, let cost, let m, let c, let seq):    conversationRuntime.handleRunStats(durationMs: ms, costUsd: cost, model: m, conversationId: c, seq: seq)
            case .resumeFromResponse(let sid, let events, let historyOnly): conversationRuntime.handleResumeFromResponse(sessionId: sid, events: events, historyOnly: historyOnly)
            case .sessionId(let id, let c):                   conversationRuntime.handleSessionId(id, conversationId: c)
            case .messageUUID(let uuid, let c):               conversationRuntime.handleMessageUUID(uuid, conversationId: c)
            case .directoryListing(let path, let entries):    files.handleDirectoryListing(path: path, entries: entries)
            case .fileContent(let p, let d, let m, let s, let t): files.handleFileContent(path: p, data: d, mimeType: m, size: s, truncated: t)
            case .fileChunk(let p, let ci, let tc, let d, let m, let s): files.handleFileChunk(path: p, chunkIndex: ci, totalChunks: tc, data: d, mimeType: m, size: s)
            case .fileThumbnail(let p, let d, let fs):        files.handleFileThumbnail(path: p, data: d, fullSize: fs)
            case .fileSearchResults(let files):               self.files.handleSearchResults(files)
            case .gitStatusResult(let status):                git.handleStatusResult(status)
            case .gitDiffResult(let path, let diff):          git.handleDiffResult(path: path, diff: diff)
            case .gitLogResult(let path, let commits):        git.handleLogResult(path: path, commits: commits)
            case .transcription(let text):                    transcription.handleResult(text)
            case .whisperReady(let ready):                    transcription.handleReady(ready)
            case .skills(let s):                              handleSkills(store, s)
            case .defaultWorkingDirectory(let path):
                defaultWorkingDirectory = path
                store.events.send(.defaultWorkingDirectory(path: path, environmentId: environmentId))
            case .historySync(let sid, let msgs):             store.events.send(.historySync(sessionId: sid, messages: msgs))
            case .historySyncError(let sid, let err):         store.events.send(.historySyncError(sessionId: sid, error: err))
            case .nameSuggestion(let name, let sym, let c):   conversationRuntime.handleNameSuggestion(name: name, symbol: sym, conversationId: c)
            case .pong(let sentAt, _):                        latencyMs = (Date().timeIntervalSince1970 - sentAt) * 1000
            case .gitCommitResult:                            break
            }
        }
    }
}
