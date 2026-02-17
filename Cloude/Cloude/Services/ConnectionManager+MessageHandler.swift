import Foundation
import Combine
import CloudeShared

extension ConnectionManager {
    func targetConversationId(from conversationId: String?) -> UUID? {
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
        case .runStats(let ms, let cost, let m, let c):    handleRunStats(durationMs: ms, costUsd: cost, model: m, conversationId: c)
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
        case .ttsAudio(let audio, let msgId):             handleTTSAudio(audioBase64: audio, messageId: msgId)
        case .kokoroReady(let ready):                     handleKokoroReady(ready)
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
        case .usageStats(let stats):                        handleUsageStats(stats)
        case .scheduledTasks(let tasks):                  handleScheduledTasks(tasks)
        case .scheduledTaskUpdated(let task):             handleScheduledTaskUpdated(task)
        case .scheduledTaskDeleted(let taskId):           handleScheduledTaskDeleted(taskId: taskId)
        case .fileChange, .image, .gitCommitResult:       break
        }
    }

    private func handleTranscription(_ text: String) {
        isTranscribing = false
        events.send(.transcription(text))
    }

    private func handleWhisperReady(_ ready: Bool) {
        isWhisperReady = ready
    }

    private func handleKokoroReady(_ ready: Bool) {
        isKokoroReady = ready
    }

    private func handleTTSAudio(audioBase64: String, messageId: String) {
        if let audioData = Data(base64Encoded: audioBase64) {
            events.send(.ttsAudio(data: audioData, messageId: messageId))
        }
    }

    private func handleHeartbeatConfig(intervalMinutes: Int?, unreadCount: Int) {
        events.send(.heartbeatConfig(intervalMinutes: intervalMinutes, unreadCount: unreadCount))
    }

    private func handleMemories(_ sections: [MemorySection]) {
        events.send(.memories(sections))
    }

    private func handleSkills(_ newSkills: [Skill]) {
        skills = newSkills
        events.send(.skills(newSkills))
    }

    private func handleDefaultWorkingDirectory(_ path: String) {
        defaultWorkingDirectory = path
    }

    private func handleProcessList(_ procs: [AgentProcessInfo]) {
        processes = procs
    }

    private func handleHistorySync(sessionId: String, messages: [HistoryMessage]) {
        events.send(.historySync(sessionId: sessionId, messages: messages))
    }

    private func handleHistorySyncError(sessionId: String, error: String) {
        events.send(.historySyncError(sessionId: sessionId, error: error))
    }

    private func handleRemoteSessionList(_ sessions: [RemoteSession]) {}

    private func handleOutput(_ text: String, conversationId: String?) {
        if let convIdStr = conversationId, let convId = UUID(uuidString: convIdStr) {
            let out = output(for: convId)
            out.appendText(text)
            if !out.isRunning {
                out.isRunning = true
                runningConversationId = convId
                events.send(.conversationOutputStarted(conversationId: convId))
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
            if let stats = out.runStats {
                events.send(.lastAssistantMessageCostUpdate(conversationId: convId, costUsd: stats.costUsd))
            }
        }
        out.isRunning = (state == .running || state == .compacting)
        out.isCompacting = (state == .compacting)
        if state == .idle {
            LiveActivityManager.shared.endActivity(conversationId: convId)
            runningConversationId = nil
            if !isAnyRunning { endBackgroundStreaming() }
        } else {
            LiveActivityManager.shared.updateActivity(conversationId: convId, agentState: state)
        }
    }

    private func handleAuthResult(success: Bool, errorMessage: String?) {
        isAuthenticated = success
        if success {
            checkForMissedResponse()
            send(.getHeartbeatConfig)
            events.send(.authenticated)
        } else {
            lastError = errorMessage ?? "Authentication failed"
        }
    }

    private func handleError(_ errorMessage: String) {
        lastError = errorMessage
        events.send(.fileError(errorMessage))
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

    private func handleRunStats(durationMs: Int, costUsd: Double, model: String?, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        output(for: convId).runStats = (durationMs, costUsd, model)
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
        events.send(.missedResponse(sessionId: sessionId, text: text, completedAt: Date(), toolCalls: storedToolCalls, interruptedConversationId: interruptedConvId, interruptedMessageId: interruptedMsgId))
    }

    private func handleNoMissedResponse(sessionId: String) {
        if let interrupted = interruptedSession, interrupted.sessionId == sessionId {
            interruptedSession = nil
        }
    }

    private func handleSessionId(_ id: String, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        output(for: convId).newSessionId = id
        events.send(.sessionIdReceived(conversationId: convId, sessionId: id))
    }

    private func handleMessageUUID(_ uuid: String, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        output(for: convId).messageUUID = uuid
    }

    private func handleHeartbeatSkipped(conversationId: String?) {
        if let convId = targetConversationId(from: conversationId) {
            output(for: convId).skipped = true
        }
        events.send(.heartbeatSkipped(conversationId: conversationId.flatMap { UUID(uuidString: $0) }))
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
    }

    func handleTeamCreated(teamName: String, conversationId: String?) {
        if let id = targetConversationId(from: conversationId) { output(for: id).teamName = teamName }
    }

    func handleTeammateSpawned(teammate: TeammateInfo, conversationId: String?) {
        if let id = targetConversationId(from: conversationId) { output(for: id).teammates.append(teammate) }
    }

    func handleTeamDeleted(conversationId: String?) {
        if let id = targetConversationId(from: conversationId) {
            let o = output(for: id)
            if let teamName = o.teamName, !o.teammates.isEmpty {
                o.teamSnapshot = (name: teamName, members: o.teammates)
            }
            o.teamName = nil
            o.teammates = []
        }
    }

    func handleSuggestionsResult(suggestions: [String], conversationId: String?) {
        events.send(.suggestionsResult(suggestions: suggestions, conversationId: conversationId.flatMap { UUID(uuidString: $0) }))
    }

    func handleTeammateUpdate(teammateId: String, status: TeammateStatus?, lastMessage: String?, lastMessageAt: Date?, conversationId: String?) {
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

    private func handleUsageStats(_ stats: UsageStats) {
        events.send(.usageStats(stats))
    }

    private func handlePlans(_ stages: [String: [PlanItem]]) {
        events.send(.plans(stages))
    }

    private func handlePlanDeleted(stage: String, filename: String) {
        events.send(.planDeleted(stage: stage, filename: filename))
    }

    private func handleScheduledTasks(_ tasks: [ScheduledTask]) {
        events.send(.scheduledTasks(tasks))
    }

    private func handleScheduledTaskUpdated(_ task: ScheduledTask) {
        events.send(.scheduledTaskUpdated(task))
    }

    private func handleScheduledTaskDeleted(taskId: String) {
        events.send(.scheduledTaskDeleted(taskId: taskId))
    }
}
