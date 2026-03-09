import Foundation
import Combine
import CloudeShared

extension EnvironmentConnection {
    func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(ServerMessage.self, from: data),
              let mgr = manager else { return }

        switch message {
        case .output(let text, let conversationId):       handleOutput(mgr, text: text, conversationId: conversationId)
        case .status(let state, let conversationId):      handleStatus(mgr, state: state, conversationId: conversationId)
        case .authRequired:                               authenticate()
        case .authResult(let success, let msg):           handleAuthResult(mgr, success: success, errorMessage: msg)
        case .error(let msg):                             handleError(mgr, msg)
        case .toolCall(let n, let i, let t, let p, let c, let pos): handleToolCall(mgr, name: n, input: i, toolId: t, parentToolId: p, conversationId: c, textPosition: pos)
        case .toolResult(let id, let sum, let out, let c):  handleToolResult(mgr, toolId: id, summary: sum, output: out, conversationId: c)
        case .runStats(let ms, let cost, let m, let c):    handleRunStats(mgr, durationMs: ms, costUsd: cost, model: m, conversationId: c)
        case .missedResponse(let sid, let t, _, let tc):  handleMissedResponse(mgr, sessionId: sid, text: t, storedToolCalls: tc)
        case .noMissedResponse(let sid):                  handleNoMissedResponse(sessionId: sid)
        case .sessionId(let id, let c):                   handleSessionId(mgr, id, conversationId: c)
        case .messageUUID(let uuid, let c):               handleMessageUUID(mgr, uuid, conversationId: c)
        case .directoryListing(let path, let entries):    mgr.events.send(.directoryListing(path: path, entries: entries))
        case .fileContent(let p, let d, let m, let s, let t): handleFileContent(mgr, path: p, data: d, mimeType: m, size: s, truncated: t)
        case .fileChunk(let p, let ci, let tc, let d, let m, let s): handleFileChunk(mgr, path: p, chunkIndex: ci, totalChunks: tc, data: d, mimeType: m, size: s)
        case .fileThumbnail(let p, let d, let fs):        mgr.events.send(.fileThumbnail(path: p, data: d, fullSize: fs))
        case .fileSearchResults(let files, let query):    mgr.events.send(.fileSearchResults(files: files, query: query))
        case .gitStatusResult(let status):                handleGitStatusResult(mgr, status)
        case .gitDiffResult(let path, let diff):          mgr.events.send(.gitDiff(path: path, diff: diff))
        case .transcription(let text):                    handleTranscription(mgr, text)
        case .whisperReady(let ready):                    isWhisperReady = ready
        case .ttsAudio, .kokoroReady:                     break
        case .heartbeatConfig(let min, let count):        mgr.events.send(.heartbeatConfig(intervalMinutes: min, unreadCount: count))
        case .heartbeatSkipped(let c):                    handleHeartbeatSkipped(mgr, conversationId: c)
        case .memories(let sections):                     mgr.events.send(.memories(sections))
        case .memoryAdded(let t, let s, let txt, let c):  handleMemoryAdded(mgr, target: t, section: s, text: txt, conversationId: c)
        case .skills(let s):                              handleSkills(mgr, s)
        case .defaultWorkingDirectory(let path):          defaultWorkingDirectory = path
        case .processList(let procs):                     processes = procs
        case .historySync(let sid, let msgs):             mgr.events.send(.historySync(sessionId: sid, messages: msgs))
        case .historySyncError(let sid, let err):          mgr.events.send(.historySyncError(sessionId: sid, error: err))
        case .remoteSessionList:                          break
        case .renameConversation(let name, let c):        handleRenameConversation(mgr, conversationId: c, name: name)
        case .setConversationSymbol(let sym, let c):      handleSetConversationSymbol(mgr, conversationId: c, symbol: sym)
        case .deleteConversation(let c):                  handleDeleteConversation(mgr, conversationId: c)
        case .switchConversation(let c):                  handleSwitchConversation(mgr, conversationId: c)
        case .notify(let title, let body, _):             mgr.events.send(.notify(title: title, body: body))
        case .clipboard(let text):                        mgr.events.send(.clipboard(text))
        case .openURL(let url):                           mgr.events.send(.openURL(url))
        case .haptic(let style):                          mgr.events.send(.haptic(style))
        case .speak(let text):                            mgr.events.send(.speak(text))
        case .question(let qs, let c):                    handleQuestion(mgr, questions: qs, conversationId: c)
        case .screenshot(let c):                          handleScreenshot(mgr, conversationId: c)
        case .teamCreated(let name, _, let c):            handleTeamCreated(mgr, teamName: name, conversationId: c)
        case .teammateSpawned(let mate, let c):           handleTeammateSpawned(mgr, teammate: mate, conversationId: c)
        case .teammateUpdate(let tid, let st, let msg, let at, let c): handleTeammateUpdate(mgr, teammateId: tid, status: st, lastMessage: msg, lastMessageAt: at, conversationId: c)
        case .teamDeleted(let c):                         handleTeamDeleted(mgr, conversationId: c)
        case .suggestionsResult(let s, let c):              mgr.events.send(.suggestionsResult(suggestions: s, conversationId: c.flatMap { UUID(uuidString: $0) }))
        case .nameSuggestion(let name, let sym, let c):   handleNameSuggestion(mgr, name: name, symbol: sym, conversationId: c)
        case .plans(let stages):                          mgr.events.send(.plans(stages))
        case .planDeleted(let stage, let filename):       mgr.events.send(.planDeleted(stage: stage, filename: filename))
        case .usageStats(let stats):                        mgr.events.send(.usageStats(stats))
        case .scheduledTasks(let tasks):                  mgr.events.send(.scheduledTasks(tasks))
        case .scheduledTaskUpdated(let task):             mgr.events.send(.scheduledTaskUpdated(task))
        case .scheduledTaskDeleted(let taskId):           mgr.events.send(.scheduledTaskDeleted(taskId: taskId))
        case .fileChange, .image, .gitCommitResult:       break
        }
    }

    func handleDisconnect() {
        guard let mgr = manager else { return }
        if let convId = runningConversationId,
           let output = mgr.conversationOutputs[convId] {
            output.flushBuffer()
            for i in output.toolCalls.indices where output.toolCalls[i].state == .executing {
                output.toolCalls[i].state = .complete
            }
            if !output.text.isEmpty {
                mgr.events.send(.disconnect(conversationId: convId, output: output))
            }
            output.isRunning = false
        }
        isConnected = false
        isAuthenticated = false
        isWhisperReady = false
        isTranscribing = false
        agentState = .idle
        runningConversationId = nil
        gitStatusQueue.removeAll()
        gitStatusInFlightPath = nil
        mgr.endBackgroundStreaming()
        mgr.objectWillChange.send()
    }

    func targetConversationId(from conversationId: String?) -> UUID? {
        conversationId.flatMap { UUID(uuidString: $0) } ?? runningConversationId
    }

    func sendNextGitStatusIfNeeded() {
        guard gitStatusInFlightPath == nil, !gitStatusQueue.isEmpty else { return }
        let next = gitStatusQueue.removeFirst()
        gitStatusInFlightPath = next
        send(.gitStatus(path: next))
    }
}
