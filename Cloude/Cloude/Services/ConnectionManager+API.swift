import Foundation
import Combine
import CloudeShared

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
        case .toolResult(let id, let sum, let out, let c):  handleToolResult(toolId: id, summary: sum, output: out, conversationId: c)
        case .runStats(let ms, let cost, let c):          handleRunStats(durationMs: ms, costUsd: cost, conversationId: c)
        case .missedResponse(let sid, let t, _, let tc):  handleMissedResponse(sessionId: sid, text: t, storedToolCalls: tc)
        case .noMissedResponse(let sid):                  handleNoMissedResponse(sessionId: sid)
        case .sessionId(let id, let c):                   handleSessionId(id, conversationId: c)
        case .messageUUID(let uuid, let c):               handleMessageUUID(uuid, conversationId: c)
        case .directoryListing(let path, let entries):    handleDirectoryListing(path: path, entries: entries)
        case .fileContent(let p, let d, let m, let s, let t): handleFileContent(path: p, data: d, mimeType: m, size: s, truncated: t)
        case .fileChunk(let p, let ci, let tc, let d, let m, let s): handleFileChunk(path: p, chunkIndex: ci, totalChunks: tc, data: d, mimeType: m, size: s)
        case .fileThumbnail(let p, let d, let fs):        handleFileThumbnail(path: p, data: d, fullSize: fs)
        case .fileSearchResults(let files, let query):    handleFileSearchResults(files: files, query: query)
        case .gitStatusResult(let status):                handleGitStatusResult(status)
        case .gitDiffResult(let path, let diff):          handleGitDiffResult(path: path, diff: diff)
        case .transcription(let text):                    handleTranscription(text)
        case .whisperReady(let ready):                    handleWhisperReady(ready)
        case .heartbeatConfig(let min, let count):        handleHeartbeatConfig(intervalMinutes: min, unreadCount: count)
        case .heartbeatSkipped(let c):                    handleHeartbeatSkipped(conversationId: c)
        case .memories(let sections):                     handleMemories(sections)
        case .memoryAdded(let t, let s, let txt, let c):  handleMemoryAdded(target: t, section: s, text: txt, conversationId: c)
        case .skills(let s):                              handleSkills(s)
        case .defaultWorkingDirectory(let path):          handleDefaultWorkingDirectory(path)
        case .processList(let procs):                     handleProcessList(procs)
        case .historySync(let sid, let msgs):             handleHistorySync(sessionId: sid, messages: msgs)
        case .historySyncError(let sid, let err):          handleHistorySyncError(sessionId: sid, error: err)
        case .remoteSessionList(let sessions):            handleRemoteSessionList(sessions)
        case .renameConversation(let name, let c):        handleRenameConversation(conversationId: c, name: name)
        case .setConversationSymbol(let sym, let c):      handleSetConversationSymbol(conversationId: c, symbol: sym)
        case .deleteConversation(let c):                  handleDeleteConversation(conversationId: c)
        case .switchConversation(let c):                  handleSwitchConversation(conversationId: c)
        case .notify(let title, let body, _):             handleNotify(title: title, body: body)
        case .clipboard(let text):                        handleClipboard(text)
        case .openURL(let url):                           handleOpenURL(url)
        case .haptic(let style):                          handleHaptic(style)
        case .speak(let text):                            handleSpeak(text)
        case .question(let qs, let c):                    handleQuestion(questions: qs, conversationId: c)
        case .screenshot(let c):                          handleScreenshot(conversationId: c)
        case .teamCreated(let name, _, let c):            handleTeamCreated(teamName: name, conversationId: c)
        case .teammateSpawned(let mate, let c):           handleTeammateSpawned(teammate: mate, conversationId: c)
        case .teammateUpdate(let tid, let st, let msg, let at, let c): handleTeammateUpdate(teammateId: tid, status: st, lastMessage: msg, lastMessageAt: at, conversationId: c)
        case .teamDeleted(let c):                         handleTeamDeleted(conversationId: c)
        case .suggestionsResult(let s, let c):              handleSuggestionsResult(suggestions: s, conversationId: c)
        case .nameSuggestion(let name, let sym, let c):   handleNameSuggestion(name: name, symbol: sym, conversationId: c)
        case .plans(let stages):                          handlePlans(stages)
        case .planDeleted(let stage, let filename):       handlePlanDeleted(stage: stage, filename: filename)
        case .planUploaded(let stage, let plan):          handlePlanUploaded(stage: stage, plan: plan)
        case .fileChange, .image, .gitCommitResult:       break
        }
    }

    private func handleDirectoryListing(path: String, entries: [FileEntry]) {
        events.send(.directoryListing(path: path, entries: entries))
        onDirectoryListing?(path, entries)
    }

    private func handleFileContent(path: String, data: String, mimeType: String, size: Int64, truncated: Bool) {
        events.send(.fileContent(path: path, data: data, mimeType: mimeType, size: size, truncated: truncated))
        onFileContent?(path, data, mimeType, size, truncated)
    }

    private func handleFileThumbnail(path: String, data: String, fullSize: Int64) {
        events.send(.fileThumbnail(path: path, data: data, fullSize: fullSize))
    }

    private func handleFileSearchResults(files: [String], query: String) {
        onFileSearchResults?(files, query)
    }

    private func handleGitStatusResult(_ status: GitStatusInfo) {
        events.send(.gitStatus(status))
        onGitStatus?(status)
    }

    private func handleGitDiffResult(path: String, diff: String) {
        events.send(.gitDiff(path: path, diff: diff))
        onGitDiff?(path, diff)
    }

    private func handleTranscription(_ text: String) {
        isTranscribing = false
        events.send(.transcription(text))
        onTranscription?(text)
    }

    private func handleWhisperReady(_ ready: Bool) {
        isWhisperReady = ready
    }

    private func handleHeartbeatConfig(intervalMinutes: Int?, unreadCount: Int) {
        events.send(.heartbeatConfig(intervalMinutes: intervalMinutes, unreadCount: unreadCount))
        onHeartbeatConfig?(intervalMinutes, unreadCount)
    }

    private func handleMemories(_ sections: [MemorySection]) {
        events.send(.memories(sections))
        onMemories?(sections)
    }

    private func handleSkills(_ newSkills: [Skill]) {
        skills = newSkills
        events.send(.skills(newSkills))
        onSkills?(newSkills)
    }

    private func handleDefaultWorkingDirectory(_ path: String) {
        defaultWorkingDirectory = path
    }

    private func handleProcessList(_ procs: [AgentProcessInfo]) {
        processes = procs
        onProcessList?(procs)
    }

    private func handleHistorySync(sessionId: String, messages: [HistoryMessage]) {
        events.send(.historySync(sessionId: sessionId, messages: messages))
        onHistorySync?(sessionId, messages)
    }

    private func handleHistorySyncError(sessionId: String, error: String) {
        events.send(.historySyncError(sessionId: sessionId, error: error))
        onHistorySyncError?(sessionId, error)
    }

    private func handleRemoteSessionList(_ sessions: [RemoteSession]) {
        onRemoteSessionList?(sessions)
    }

    private func handleRenameConversation(conversationId: String, name: String) {
        if let id = UUID(uuidString: conversationId) { onRenameConversation?(id, name) }
    }

    private func handleSetConversationSymbol(conversationId: String, symbol: String?) {
        if let id = UUID(uuidString: conversationId) { onSetConversationSymbol?(id, symbol) }
    }

    private func handleDeleteConversation(conversationId: String) {
        if let id = UUID(uuidString: conversationId) { onDeleteConversation?(id) }
    }

    private func handleSwitchConversation(conversationId: String) {
        if let id = UUID(uuidString: conversationId) { onSwitchConversation?(id) }
    }

    private func handleNotify(title: String?, body: String) {
        onNotify?(title, body)
    }

    private func handleClipboard(_ text: String) {
        onClipboard?(text)
    }

    private func handleOpenURL(_ url: String) {
        onOpenURL?(url)
    }

    private func handleHaptic(_ style: String) {
        onHaptic?(style)
    }

    private func handleSpeak(_ text: String) {
        onSpeak?(text)
    }

    private func handleQuestion(questions: [Question], conversationId: String?) {
        onQuestion?(questions, conversationId.flatMap { UUID(uuidString: $0) })
    }

    private func handleScreenshot(conversationId: String?) {
        onScreenshot?(conversationId.flatMap { UUID(uuidString: $0) })
    }

    private func handleTeamCreated(teamName: String, conversationId: String?) {
        if let id = targetConversationId(from: conversationId) { output(for: id).teamName = teamName }
    }

    private func handleTeammateSpawned(teammate: TeammateInfo, conversationId: String?) {
        if let id = targetConversationId(from: conversationId) { output(for: id).teammates.append(teammate) }
    }

    private func handleTeamDeleted(conversationId: String?) {
        if let id = targetConversationId(from: conversationId) {
            let o = output(for: id)
            if let teamName = o.teamName, !o.teammates.isEmpty {
                o.teamSnapshot = (name: teamName, members: o.teammates)
            }
            o.teamName = nil
            o.teammates = []
        }
    }

    private func handleSuggestionsResult(suggestions: [String], conversationId: String?) {
        onSuggestionsResult?(suggestions, conversationId.flatMap { UUID(uuidString: $0) })
    }

    private func handleNameSuggestion(name: String, symbol: String?, conversationId: String) {
        if let id = UUID(uuidString: conversationId) {
            onRenameConversation?(id, name)
            if let s = symbol { onSetConversationSymbol?(id, s) }
        }
    }

    private func handleOutput(_ text: String, conversationId: String?) {
        if let convIdStr = conversationId, let convId = UUID(uuidString: convIdStr) {
            let out = output(for: convId)
            out.appendText(text)
            if !out.isRunning {
                out.isRunning = true
                runningConversationId = convId
                onConversationOutputStarted?(convId)
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
            onAuthenticated?()
        } else {
            lastError = errorMessage ?? "Authentication failed"
        }
    }

    private func handleError(_ errorMessage: String) {
        lastError = errorMessage
        onFileError?(errorMessage)
        if errorMessage.lowercased().contains("transcription") && isTranscribing {
            isTranscribing = false
            AudioRecorder.markTranscriptionFailed()
        }
    }

    private func handleToolCall(name: String, input: String?, toolId: String, parentToolId: String?, conversationId: String?, textPosition: Int?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        let currentTextLength = output(for: convId).fullText.count
        let position = min(textPosition ?? currentTextLength, currentTextLength)
        output(for: convId).toolCalls.append(ToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, textPosition: position, state: .executing))
        let detail = input.flatMap { ToolInputExtractor.extractDisplayDetail(name: name, jsonString: $0) }
        LiveActivityManager.shared.updateActivity(conversationId: convId, agentState: .running, currentTool: name, toolDetail: detail)
    }

    private func handleToolResult(toolId: String, summary: String?, output: String?, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        let out = self.output(for: convId)
        if let idx = out.toolCalls.firstIndex(where: { $0.toolId == toolId }) {
            out.toolCalls[idx].state = .complete
            out.toolCalls[idx].resultSummary = summary
            out.toolCalls[idx].resultOutput = output
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
            if let msg = lastMessage {
                let ts = lastMessageAt ?? Date()
                out.teammates[idx].lastMessage = msg
                out.teammates[idx].lastMessageAt = ts
                out.teammates[idx].appendMessage(msg, at: ts)
            } else if let ts = lastMessageAt {
                out.teammates[idx].lastMessageAt = ts
            }
        }
    }

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

    private func handlePlans(_ stages: [String: [PlanItem]]) {
        onPlans?(stages)
    }

    private func handlePlanDeleted(stage: String, filename: String) {
        onPlanDeleted?(stage, filename)
    }

    private func handlePlanUploaded(stage: String, plan: PlanItem) {
        onPlanUploaded?(stage, plan)
    }

    func getPlans(workingDirectory: String)                        { ensureAuthenticated(); send(.getPlans(workingDirectory: workingDirectory)) }
    func deletePlan(stage: String, filename: String, workingDirectory: String) { ensureAuthenticated(); send(.deletePlan(stage: stage, filename: filename, workingDirectory: workingDirectory)) }
    func uploadPlan(stage: String, filename: String, content: String, workingDirectory: String) { ensureAuthenticated(); send(.uploadPlan(stage: stage, filename: filename, content: content, workingDirectory: workingDirectory)) }

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

    func requestSuggestions(context: [String], workingDirectory: String?, conversationId: UUID?) {
        ensureAuthenticated()
        send(.requestSuggestions(context: context, workingDirectory: workingDirectory, conversationId: conversationId?.uuidString))
    }

    func requestNameSuggestion(text: String, context: [String], conversationId: UUID) {
        ensureAuthenticated()
        send(.suggestName(text: text, context: context, conversationId: conversationId.uuidString))
    }
}
