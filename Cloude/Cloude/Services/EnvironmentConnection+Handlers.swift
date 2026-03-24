// EnvironmentConnection+Handlers.swift

import Foundation
import Combine
import CloudeShared

extension EnvironmentConnection {
    private func ensureLiveMessage(_ mgr: ConnectionManager, convId: UUID) {
        let out = mgr.output(for: convId)
        if out.liveMessageId == nil {
            out.reset()
            mgr.events.send(.streamingStarted(conversationId: convId))
        }
    }

    func handleOutput(_ mgr: ConnectionManager, text: String, conversationId: String?) {
        if let convIdStr = conversationId, let convId = UUID(uuidString: convIdStr) {
            ensureLiveMessage(mgr, convId: convId)
            let out = mgr.output(for: convId)
            out.appendText(text)
            if !out.isRunning {
                out.isRunning = true
                runningConversationId = convId
            }
        } else if let convId = runningConversationId {
            ensureLiveMessage(mgr, convId: convId)
            mgr.output(for: convId).appendText(text)
        }
    }

    func handleStatus(_ mgr: ConnectionManager, state: AgentState, conversationId: String?) {
        if agentState != state { agentState = state }
        guard let convId = targetConversationId(from: conversationId) else { return }
        let out = mgr.output(for: convId)
        if state == .idle {
            out.flushBuffer()
            out.completeExecutingTools()
            if let stats = out.runStats {
                let turnCost = max(0, stats.costUsd - out.previousCumulativeCost)
                out.previousCumulativeCost = stats.costUsd
                mgr.events.send(.lastAssistantMessageCostUpdate(conversationId: convId, costUsd: turnCost))
            }
        }
        out.isRunning = (state == .running || state == .compacting)
        out.isCompacting = (state == .compacting)
        if state == .running || state == .compacting {
            ensureLiveMessage(mgr, convId: convId)
        }
        if state == .idle {
            LiveActivityManager.shared.endActivity(conversationId: convId)
            runningConversationId = nil
            if !mgr.isAnyRunning { mgr.endBackgroundStreaming() }
        } else {
            LiveActivityManager.shared.updateActivity(conversationId: convId, agentState: state)
        }
    }

    func handleAuthResult(_ mgr: ConnectionManager, success: Bool, errorMessage: String?) {
        isAuthenticated = success
        if success {
            checkForMissedResponse()
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
        ensureLiveMessage(mgr, convId: convId)
        let currentTextLength = mgr.output(for: convId).fullText.count
        let position = min(textPosition ?? currentTextLength, currentTextLength)
        mgr.output(for: convId).toolCalls.append(ToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, textPosition: position, state: .executing, editInfo: editInfo))
        if name.hasPrefix("mcp__ios__") {
            handleIOSToolCall(mgr, name: name, input: input, conversationId: conversationId)
            return
        }
        let detail = input.flatMap { ToolInputExtractor.extractDisplayDetail(name: name, jsonString: $0) }
        LiveActivityManager.shared.updateActivity(conversationId: convId, agentState: .running, currentTool: name, toolDetail: detail)
    }

    func handleToolResult(_ mgr: ConnectionManager, toolId: String, summary: String?, output: String?, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        let out = mgr.output(for: convId)
        if let idx = out.toolCalls.firstIndex(where: { $0.toolId == toolId }) {
            out.toolCalls[idx].state = .complete
            out.toolCalls[idx].resultSummary = summary
            out.toolCalls[idx].resultOutput = output
        }
    }

    func handleRunStats(_ mgr: ConnectionManager, durationMs: Int, costUsd: Double, model: String?, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        mgr.output(for: convId).runStats = (durationMs, costUsd, model)
    }

    func handleMissedResponse(_ mgr: ConnectionManager, sessionId: String, text: String, storedToolCalls: [StoredToolCall]) {
        var interruptedConvId: UUID?
        var interruptedMsgId: UUID?
        let toolCalls = storedToolCalls.map { ToolCall(from: $0) }
        if let interrupted = interruptedSession, interrupted.sessionId == sessionId {
            interruptedConvId = interrupted.conversationId
            interruptedMsgId = interrupted.messageId
            let missedOutput = mgr.output(for: interrupted.conversationId)
            missedOutput.fullText = text
            missedOutput.text = text
            missedOutput.toolCalls = toolCalls
            missedOutput.isRunning = false
            interruptedSession = nil
        }
        mgr.events.send(.missedResponse(sessionId: sessionId, text: text, completedAt: Date(), toolCalls: storedToolCalls, interruptedConversationId: interruptedConvId, interruptedMessageId: interruptedMsgId))
    }

    func handleNoMissedResponse(sessionId: String) {
        if let interrupted = interruptedSession, interrupted.sessionId == sessionId {
            interruptedSession = nil
        }
    }

    func handleSessionId(_ mgr: ConnectionManager, _ id: String, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
        mgr.output(for: convId).newSessionId = id
        mgr.events.send(.sessionIdReceived(conversationId: convId, sessionId: id))
    }

    func handleMessageUUID(_ mgr: ConnectionManager, _ uuid: String, conversationId: String?) {
        guard let convId = targetConversationId(from: conversationId) else { return }
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
