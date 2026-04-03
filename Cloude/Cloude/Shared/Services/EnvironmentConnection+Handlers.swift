// EnvironmentConnection+Handlers.swift

import Foundation
import Combine
import CloudeShared

extension EnvironmentConnection {
    private func ensureRunning(_ out: ConversationOutput) {
        if !out.isRunning { out.isRunning = true }
    }

    func handleOutput(_ mgr: ConnectionManager, text: String, conversationId: String?) {
        guard let convId = conversationId.flatMap({ UUID(uuidString: $0) }) else { return }
        AppLogger.connectionInfo("assistant output convId=\(convId.uuidString) chars=\(text.count)")
        AppLogger.endInterval("chat.firstToken", key: convId.uuidString)
        let out = mgr.output(for: convId)
        out.completeTopLevelExecutingTools()
        out.appendText(text)
        ensureRunning(out)
    }

    func handleStatus(_ mgr: ConnectionManager, state: AgentState, conversationId: String?) {
        if agentState != state { agentState = state }
        guard let convId = targetConversationId(from: conversationId) else { return }
        AppLogger.connectionInfo("status convId=\(convId.uuidString) state=\(state.rawValue)")
        let out = mgr.output(for: convId)
        if state == .idle {
            out.flushBuffer()
            out.completeExecutingTools()
            AppLogger.cancelInterval("chat.firstToken", key: convId.uuidString, reason: "idle")
            AppLogger.cancelInterval("chat.complete", key: convId.uuidString, reason: "idle")
            if let stats = out.runStats {
                let turnCost = max(0, stats.costUsd - out.previousCumulativeCost)
                out.previousCumulativeCost = stats.costUsd
                mgr.events.send(.lastAssistantMessageCostUpdate(conversationId: convId, costUsd: turnCost))
            }
        }
        let wasRunning = out.isRunning
        out.isRunning = (state == .running || state == .compacting)
        out.isCompacting = (state == .compacting)
        if state == .running || state == .compacting {
            if !wasRunning {
                mgr.events.send(.reconnectRunning(conversationId: convId))
            }
        }
        if state == .idle {
            if wasRunning { mgr.events.send(.turnCompleted(conversationId: convId)) }
            if !mgr.isAnyRunning { mgr.endBackgroundStreaming() }
        }
    }

    func handleAuthResult(_ mgr: ConnectionManager, success: Bool, errorMessage: String?) {
        isAuthenticated = success
        if success {
            checkForMissedResponse()
            sendNextGitStatusIfNeeded()
            mgr.events.send(.authenticated)
            mgr.objectWillChange.send()
        } else {
            lastError = errorMessage ?? "Authentication failed"
        }
    }

    func handleError(_ mgr: ConnectionManager, _ errorMessage: String) {
        lastError = errorMessage
        mgr.events.send(.fileError(errorMessage))
        if errorMessage.lowercased().contains("transcription") && isTranscribing {
            isTranscribing = false
            AudioRecorder.markTranscriptionFailed()
        }
    }

    func handleToolCall(_ mgr: ConnectionManager, name: String, input: String?, toolId: String, parentToolId: String?, conversationId: String?, textPosition: Int?, editInfo: EditInfo? = nil) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        AppLogger.connectionInfo("tool call convId=\(convId.uuidString) toolId=\(toolId) name=\(name)")
        let out = mgr.output(for: convId)
        ensureRunning(out)
        if parentToolId == nil {
            out.completeTopLevelExecutingTools()
        }
        let currentTextLength = out.fullText.count
        let position = min(textPosition ?? currentTextLength, currentTextLength)
        out.toolCalls.append(ToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, textPosition: position, state: .executing, editInfo: editInfo))
        if name.hasPrefix("mcp__ios__") {
            handleIOSToolCall(mgr, name: name, input: input, conversationId: conversationId)
            return
        }
        if name.hasPrefix("mcp__whiteboard__") {
            handleWhiteboardToolCall(mgr, name: name, input: input, conversationId: conversationId)
            return
        }
    }

    func handleToolResult(_ mgr: ConnectionManager, toolId: String, summary: String?, output: String?, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        AppLogger.connectionInfo("tool result convId=\(convId.uuidString) toolId=\(toolId) summaryChars=\(summary?.count ?? 0) outputChars=\(output?.count ?? 0)")
        let out = mgr.output(for: convId)
        out.toolCalls = out.toolCalls.map { tool in
            if tool.toolId == toolId {
                var updated = tool
                updated.state = .complete
                updated.resultSummary = summary
                updated.resultOutput = output
                return updated
            }
            return tool
        }
    }

    func handleRunStats(_ mgr: ConnectionManager, durationMs: Int, costUsd: Double, model: String?, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        AppLogger.connectionInfo("run stats convId=\(convId.uuidString) durationMs=\(durationMs) costUsd=\(costUsd)")
        AppLogger.endInterval("chat.complete", key: convId.uuidString, details: "serverDurationMs=\(durationMs) costUsd=\(costUsd)")
        mgr.output(for: convId).runStats = (durationMs, costUsd, model)
    }

    func handleMissedResponse(_ mgr: ConnectionManager, sessionId: String, text: String, storedToolCalls: [StoredToolCall]) {
        var interruptedConvId: UUID?
        var interruptedMsgId: UUID?
        if let interrupted = interruptedSession, interrupted.sessionId == sessionId {
            interruptedConvId = interrupted.conversationId
            interruptedMsgId = interrupted.messageId
            interruptedSession = nil
        }
        mgr.events.send(.missedResponse(sessionId: sessionId, text: text, completedAt: Date(), toolCalls: storedToolCalls, interruptedConversationId: interruptedConvId, interruptedMessageId: interruptedMsgId))
        if let convId = interruptedConvId {
            let output = mgr.output(for: convId)
            output.reset()
            output.isRunning = false
        }
    }

    func handleNoMissedResponse(_ mgr: ConnectionManager, sessionId: String) {
        if let interrupted = interruptedSession, interrupted.sessionId == sessionId {
            interruptedSession = nil
            mgr.events.send(.reconnectRunning(conversationId: interrupted.conversationId))
        }
    }

    func handleSessionId(_ mgr: ConnectionManager, _ id: String, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        AppLogger.connectionInfo("session id convId=\(convId.uuidString) sessionId=\(id)")
        mgr.output(for: convId).newSessionId = id
        mgr.events.send(.sessionIdReceived(conversationId: convId, sessionId: id))
    }

    func handleMessageUUID(_ mgr: ConnectionManager, _ uuid: String, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        AppLogger.connectionInfo("message uuid convId=\(convId.uuidString) uuid=\(uuid)")
        mgr.output(for: convId).messageUUID = uuid
    }

    func handleTranscription(_ mgr: ConnectionManager, _ text: String) {
        isTranscribing = false
        mgr.events.send(.transcription(text))
    }

    func handleSkills(_ mgr: ConnectionManager, _ newSkills: [Skill]) {
        skills = newSkills
        mgr.events.send(.skills(newSkills))
    }
}
