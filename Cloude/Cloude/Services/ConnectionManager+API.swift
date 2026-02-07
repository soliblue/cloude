import Foundation
import Combine
import CloudeShared

private func extractToolDetail(name: String, input: String) -> String? {
    switch name {
    case "Bash":
        if let data = input.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let command = json["command"] as? String {
            let firstLine = command.components(separatedBy: .newlines).first ?? command
            let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
            if trimmed.count > 40 {
                return String(trimmed.prefix(37)) + "..."
            }
            return trimmed
        }
    case "Read", "Write", "Edit":
        if let data = input.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let path = json["file_path"] as? String {
            return path.lastPathComponent
        }
    case "Grep":
        if let data = input.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let pattern = json["pattern"] as? String {
            if pattern.count > 30 {
                return String(pattern.prefix(27)) + "..."
            }
            return pattern
        }
    case "Glob":
        if let data = input.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let pattern = json["pattern"] as? String {
            return pattern
        }
    case "Task":
        if let data = input.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let desc = json["description"] as? String {
            return desc
        }
    default:
        break
    }
    return nil
}

extension ConnectionManager {
    private func targetConversationId(from conversationId: String?) -> UUID? {
        conversationId.flatMap { UUID(uuidString: $0) } ?? runningConversationId
    }

    func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(ServerMessage.self, from: data) else {
            return
        }

        switch message {
        case .output(let text, let conversationId):       handleOutput(text, conversationId: conversationId)
        case .status(let state, let conversationId):      handleStatus(state, conversationId: conversationId)
        case .authRequired:                               authenticate()
        case .authResult(let success, let msg):           handleAuthResult(success: success, errorMessage: msg)
        case .error(let msg):                             handleError(msg)
        case .toolCall(let n, let i, let t, let p, let c, let pos): handleToolCall(name: n, input: i, toolId: t, parentToolId: p, conversationId: c, textPosition: pos)
        case .toolResult(let id, let sum, let c):         handleToolResult(toolId: id, summary: sum, conversationId: c)
        case .runStats(let ms, let cost, let c):          handleRunStats(durationMs: ms, costUsd: cost, conversationId: c)
        case .missedResponse(let sid, let t, _, let tc):  handleMissedResponse(sessionId: sid, text: t, storedToolCalls: tc)
        case .noMissedResponse(let sid):                  handleNoMissedResponse(sessionId: sid)
        case .sessionId(let id, let c):                   handleSessionId(id, conversationId: c)
        case .messageUUID(let uuid, let c):               handleMessageUUID(uuid, conversationId: c)

        case .directoryListing(let path, let entries):    events.send(.directoryListing(path: path, entries: entries)); onDirectoryListing?(path, entries)
        case .fileContent(let p, let d, let m, let s, let t): events.send(.fileContent(path: p, data: d, mimeType: m, size: s, truncated: t)); onFileContent?(p, d, m, s, t)
        case .fileChunk(let p, let ci, let tc, let d, let m, let s): handleFileChunk(path: p, chunkIndex: ci, totalChunks: tc, data: d, mimeType: m, size: s)
        case .fileThumbnail(let p, let d, let fs):        events.send(.fileThumbnail(path: p, data: d, fullSize: fs))
        case .fileSearchResults(let files, let query):    onFileSearchResults?(files, query)

        case .gitStatusResult(let status):                events.send(.gitStatus(status)); onGitStatus?(status)
        case .gitDiffResult(let path, let diff):          events.send(.gitDiff(path: path, diff: diff)); onGitDiff?(path, diff)

        case .transcription(let text):                    isTranscribing = false; events.send(.transcription(text)); onTranscription?(text)
        case .whisperReady(let ready):                    isWhisperReady = ready
        case .heartbeatConfig(let min, let count):        events.send(.heartbeatConfig(intervalMinutes: min, unreadCount: count)); onHeartbeatConfig?(min, count)
        case .heartbeatSkipped(let c):                    handleHeartbeatSkipped(conversationId: c)
        case .memories(let sections):                     events.send(.memories(sections)); onMemories?(sections)
        case .memoryAdded(let t, let s, let txt, let c):  handleMemoryAdded(target: t, section: s, text: txt, conversationId: c)
        case .skills(let s):                              skills = s; events.send(.skills(s)); onSkills?(s)
        case .defaultWorkingDirectory(let path):          defaultWorkingDirectory = path
        case .processList(let procs):                     processes = procs; onProcessList?(procs)
        case .historySync(let sid, let msgs):             events.send(.historySync(sessionId: sid, messages: msgs)); onHistorySync?(sid, msgs)
        case .historySyncError(let sid, let err):          events.send(.historySyncError(sessionId: sid, error: err)); onHistorySyncError?(sid, err)
        case .remoteSessionList(let sessions):            onRemoteSessionList?(sessions)

        case .renameConversation(let c, let name):        if let id = UUID(uuidString: c) { onRenameConversation?(id, name) }
        case .setConversationSymbol(let c, let sym):      if let id = UUID(uuidString: c) { onSetConversationSymbol?(id, sym) }
        case .deleteConversation(let c):                  if let id = UUID(uuidString: c) { onDeleteConversation?(id) }
        case .switchConversation(let c):                  if let id = UUID(uuidString: c) { onSwitchConversation?(id) }
        case .notify(let title, let body, _):             onNotify?(title, body)
        case .clipboard(let text):                        onClipboard?(text)
        case .openURL(let url):                           onOpenURL?(url)
        case .haptic(let style):                          onHaptic?(style)
        case .speak(let text):                            onSpeak?(text)
        case .question(let qs, let c):                    onQuestion?(qs, c.flatMap { UUID(uuidString: $0) })
        case .screenshot(let c):                          onScreenshot?(c.flatMap { UUID(uuidString: $0) })

        case .teamCreated(let name, _, let c):            if let id = targetConversationId(from: c) { output(for: id).teamName = name }
        case .teammateSpawned(let mate, let c):           if let id = targetConversationId(from: c) { output(for: id).teammates.append(mate) }
        case .teammateUpdate(let tid, let st, let msg, let at, let c): handleTeammateUpdate(teammateId: tid, status: st, lastMessage: msg, lastMessageAt: at, conversationId: c)
        case .teamDeleted(let c):                         if let id = targetConversationId(from: c) { let o = output(for: id); o.teamName = nil; o.teammates = [] }

        case .fileChange, .image, .gitCommitResult:       break
        }
    }

    private func handleOutput(_ text: String, conversationId: String?) {
        if let convIdStr = conversationId, let convId = UUID(uuidString: convIdStr) {
            let out = output(for: convId)
            out.appendText(text)
            if !out.isRunning {
                out.isRunning = true
                runningConversationId = convId
            }
        } else if let convId = runningConversationId {
            output(for: convId).appendText(text)
        }
    }

    private func handleStatus(_ state: AgentState, conversationId: String?) {
        if agentState != state { agentState = state }
        guard let convId = targetConversationId(from: conversationId) else { return }
        let out = output(for: convId)
        if state == .idle {
            out.flushBuffer()
            for i in out.toolCalls.indices where out.toolCalls[i].state == .executing {
                out.toolCalls[i].state = .complete
            }
            if let (_, costUsd) = out.runStats {
                onLastAssistantMessageCostUpdate?(convId, costUsd)
            }
        }
        out.isRunning = (state == .running || state == .compacting)
        out.isCompacting = (state == .compacting)
        if state == .idle {
            LiveActivityManager.shared.endActivity(conversationId: convId)
            runningConversationId = nil
        } else {
            LiveActivityManager.shared.updateActivity(conversationId: convId, agentState: state)
        }
    }

    private func handleAuthResult(success: Bool, errorMessage: String?) {
        isAuthenticated = success
        if success {
            checkForMissedResponse()
            send(.getHeartbeatConfig)
        } else {
            lastError = errorMessage ?? "Authentication failed"
        }
    }

    private func handleError(_ errorMessage: String) {
        lastError = errorMessage
        if errorMessage.lowercased().contains("transcription") && isTranscribing {
            isTranscribing = false
            AudioRecorder.markTranscriptionFailed()
        }
    }

    private func handleToolCall(name: String, input: String?, toolId: String, parentToolId: String?, conversationId: String?, textPosition: Int?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        let currentTextLength = output(for: convId).fullText.count
        let position = textPosition ?? currentTextLength
        output(for: convId).toolCalls.append(ToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, textPosition: position, state: .executing))
        let detail = input.flatMap { extractToolDetail(name: name, input: $0) }
        LiveActivityManager.shared.updateActivity(conversationId: convId, agentState: .running, currentTool: name, toolDetail: detail)
    }

    private func handleToolResult(toolId: String, summary: String?, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        let out = output(for: convId)
        if let idx = out.toolCalls.firstIndex(where: { $0.toolId == toolId }) {
            out.toolCalls[idx].state = .complete
            out.toolCalls[idx].resultSummary = summary
        }
    }

    private func handleRunStats(durationMs: Int, costUsd: Double, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        output(for: convId).runStats = (durationMs, costUsd)
    }

    private func handleMissedResponse(sessionId: String, text: String, storedToolCalls: [StoredToolCall]) {
        var interruptedConvId: UUID?
        var interruptedMsgId: UUID?
        let toolCalls = storedToolCalls.map { ToolCall(name: $0.name, input: $0.input, toolId: $0.toolId, parentToolId: $0.parentToolId, textPosition: $0.textPosition) }
        if let interrupted = interruptedSession, interrupted.sessionId == sessionId {
            interruptedConvId = interrupted.conversationId
            interruptedMsgId = interrupted.messageId
            let missedOutput = output(for: interrupted.conversationId)
            missedOutput.fullText = text
            missedOutput.text = text
            missedOutput.toolCalls = toolCalls
            missedOutput.isRunning = false
            interruptedSession = nil
        }
        events.send(.missedResponse(sessionId: sessionId, text: text, completedAt: Date(), toolCalls: storedToolCalls))
        onMissedResponse?(sessionId, text, toolCalls, Date(), interruptedConvId, interruptedMsgId)
    }

    private func handleNoMissedResponse(sessionId: String) {
        if let interrupted = interruptedSession, interrupted.sessionId == sessionId {
            interruptedSession = nil
        }
    }

    private func handleSessionId(_ id: String, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        output(for: convId).newSessionId = id
        onSessionIdReceived?(convId, id)
    }

    private func handleMessageUUID(_ uuid: String, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        output(for: convId).messageUUID = uuid
    }

    private func handleFileChunk(path: String, chunkIndex: Int, totalChunks: Int, data: String, mimeType: String, size: Int64) {
        chunkProgress = ChunkProgress(path: path, current: chunkIndex, total: totalChunks)
        events.send(.fileChunk(path: path, chunkIndex: chunkIndex, totalChunks: totalChunks, data: data, mimeType: mimeType, size: size))
        if pendingChunks[path] == nil {
            pendingChunks[path] = (chunks: [:], totalChunks: totalChunks, mimeType: mimeType, size: size)
        }
        pendingChunks[path]?.chunks[chunkIndex] = data
        if let pending = pendingChunks[path], (0..<pending.totalChunks).allSatisfy({ pending.chunks[$0] != nil }) {
            var combinedData = Data()
            for i in 0..<pending.totalChunks {
                if let chunkBase64 = pending.chunks[i], let chunkData = Data(base64Encoded: chunkBase64) {
                    combinedData.append(chunkData)
                }
            }
            let combinedBase64 = combinedData.base64EncodedString()
            pendingChunks.removeValue(forKey: path)
            events.send(.fileContent(path: path, data: combinedBase64, mimeType: pending.mimeType, size: pending.size, truncated: false))
            onFileContent?(path, combinedBase64, pending.mimeType, pending.size, false)
        }
    }

    private func handleHeartbeatSkipped(conversationId: String?) {
        if let convId = targetConversationId(from: conversationId) {
            output(for: convId).skipped = true
        }
        onHeartbeatSkipped?(conversationId)
    }

    private func handleMemoryAdded(target: String, section: String, text: String, conversationId: String?) {
        if let convId = targetConversationId(from: conversationId) {
            let memoryCall = ToolCall(
                name: "Memory",
                input: "\(target): \(section) - \(text)",
                toolId: UUID().uuidString,
                parentToolId: nil,
                textPosition: output(for: convId).text.count
            )
            output(for: convId).toolCalls.append(memoryCall)
        }
        onMemoryAdded?(target, section, text)
    }

    private func handleTeammateUpdate(teammateId: String, status: TeammateStatus?, lastMessage: String?, lastMessageAt: Date?, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        let out = output(for: convId)
        if let idx = out.teammates.firstIndex(where: { $0.id == teammateId || $0.name == teammateId }) {
            if let status { out.teammates[idx].status = status }
            if let msg = lastMessage { out.teammates[idx].lastMessage = msg }
            if let ts = lastMessageAt { out.teammates[idx].lastMessageAt = ts }
        }
    }

    private func ensureAuthenticated() {
        if !isAuthenticated { reconnectIfNeeded() }
    }

    func searchFiles(query: String, workingDirectory: String) {
        ensureAuthenticated()
        send(.searchFiles(query: query, workingDirectory: workingDirectory))
    }

    func sendChat(_ message: String, workingDirectory: String? = nil, sessionId: String? = nil, isNewSession: Bool = true, conversationId: UUID? = nil, imagesBase64: [String]? = nil, conversationName: String? = nil, conversationSymbol: String? = nil, forkSession: Bool = false, effort: String? = nil, model: String? = nil) {
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
        send(.chat(message: message, workingDirectory: effectiveWorkingDir, sessionId: sessionId, isNewSession: isNewSession, imagesBase64: imagesBase64, conversationId: conversationId?.uuidString, conversationName: conversationName, forkSession: forkSession, effort: effort, model: model))
    }

    func abort(conversationId: UUID? = nil) {
        send(.abort(conversationId: conversationId?.uuidString))
    }

    func listDirectory(path: String)                              { ensureAuthenticated(); send(.listDirectory(path: path)) }
    func getFile(path: String)                                    { ensureAuthenticated(); send(.getFile(path: path)) }
    func getFileFullQuality(path: String)                         { ensureAuthenticated(); send(.getFileFullQuality(path: path)) }
    func requestMissedResponse(sessionId: String)                 { ensureAuthenticated(); send(.requestMissedResponse(sessionId: sessionId)) }
    func gitStatus(path: String)                                  { ensureAuthenticated(); send(.gitStatus(path: path)) }
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
}
