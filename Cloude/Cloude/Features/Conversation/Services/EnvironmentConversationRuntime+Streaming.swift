import Foundation
import CloudeShared

extension EnvironmentConversationRuntime {
    func handleOutput(text: String, conversationId: String?, seq: Int? = nil) {
        if let conversationId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            let conversation = conversation(for: conversationId)
            if let seq, seq <= conversation.output.lastSeenSeq {
                return
            }
            AppLogger.connectionInfo("assistant output convId=\(conversationId.uuidString) chars=\(text.count) seq=\(seq.map(String.init) ?? "nil")")
            AppLogger.endInterval("chat.firstToken", key: conversationId.uuidString)
            let output = conversation.output
            output.completeExecutingTools(topLevelOnly: true)
            output.appendText(text)
            ensureRunning(output)
            if let seq {
                output.lastSeenSeq = max(output.lastSeenSeq, seq)
            }
        }
    }

    func handleToolCall(name: String, input: String?, toolId: String, parentToolId: String?, conversationId: String?, textPosition: Int?, editInfo: EditInfo? = nil, seq: Int? = nil) {
        if let conversationId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("tool call convId=\(conversationId.uuidString) toolId=\(toolId) name=\(name) seq=\(seq.map(String.init) ?? "nil")")
            let output = conversation(for: conversationId).output
            ensureRunning(output)
            if parentToolId == nil {
                output.completeExecutingTools(topLevelOnly: true)
            }
            let currentTextLength = output.fullText.count
            let position = min(textPosition ?? currentTextLength, currentTextLength)
            output.toolCalls.append(ToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, textPosition: position, state: .executing, editInfo: editInfo))
            emitEvent?(.liveSnapshot(conversationId: conversationId))
            if let seq {
                output.lastSeenSeq = max(output.lastSeenSeq, seq)
            }
        }
    }

    func handleToolResult(toolId: String, resultOutput: String?, conversationId: String?, seq: Int? = nil) {
        if let conversationId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("tool result convId=\(conversationId.uuidString) toolId=\(toolId) outputChars=\(resultOutput?.count ?? 0) seq=\(seq.map(String.init) ?? "nil")")
            let outputState = conversation(for: conversationId).output
            if !outputState.toolCalls.contains(where: { $0.toolId == toolId }) {
                AppLogger.connectionInfo("heuristic_counter=requiresHistoryResync_flip reason=tool_result_without_call convId=\(conversationId.uuidString) toolId=\(toolId)")
                outputState.requiresHistoryResync = true
            }
            outputState.toolCalls = outputState.toolCalls.map { tool in
                if tool.toolId == toolId {
                    var updated = tool
                    updated.state = .complete
                    updated.resultOutput = resultOutput
                    return updated
                }
                return tool
            }
            if let seq {
                outputState.lastSeenSeq = max(outputState.lastSeenSeq, seq)
            }
        }
    }

    func handleRunStats(durationMs: Int, costUsd: Double, model: String?, conversationId: String?, seq: Int? = nil) {
        if let conversationId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("run stats convId=\(conversationId.uuidString) durationMs=\(durationMs) costUsd=\(costUsd) seq=\(seq.map(String.init) ?? "nil")")
            AppLogger.endInterval("chat.complete", key: conversationId.uuidString, details: "serverDurationMs=\(durationMs) costUsd=\(costUsd)")
            let output = conversation(for: conversationId).output
            output.runStats = RunStats(durationMs: durationMs, costUsd: costUsd, model: model)
            if let seq {
                output.lastSeenSeq = max(output.lastSeenSeq, seq)
            }
        }
    }

    func handleSessionId(_ id: String, conversationId: String?) {
        if let conversationId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("session id convId=\(conversationId.uuidString) sessionId=\(id)")
            conversation(for: conversationId).output.newSessionId = id
            emitEvent?(.sessionIdReceived(conversationId: conversationId, sessionId: id))
        }
    }

    func handleMessageUUID(_ uuid: String, conversationId: String?) {
        if let conversationId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("message uuid convId=\(conversationId.uuidString) uuid=\(uuid)")
            conversation(for: conversationId).output.messageUUID = uuid
        }
    }

    func handleStatus(state: AgentState, conversationId: String?) {
        if let conversationId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("status convId=\(conversationId.uuidString) state=\(state.rawValue)")
            let output = conversation(for: conversationId).output
            if state == .idle {
                output.flushBuffer()
                output.completeExecutingTools()
                AppLogger.cancelInterval("chat.firstToken", key: conversationId.uuidString, reason: "idle")
                AppLogger.cancelInterval("chat.complete", key: conversationId.uuidString, reason: "idle")
                if let stats = output.runStats, stats.costUsd > 0 {
                    emitEvent?(.lastAssistantMessageCostUpdate(conversationId: conversationId, costUsd: stats.costUsd))
                }
            }
            let oldPhase = output.phase
            output.phase = state == .running ? .running : (state == .compacting ? .compacting : .idle)
            if oldPhase == .idle && output.phase != .idle {
                emitEvent?(.reconnectRunning(conversationId: conversationId))
            }
            if state == .idle {
                if oldPhase != .idle {
                    emitEvent?(.turnCompleted(conversationId: conversationId))
                }
                if runningOutputs.isEmpty {
                    BackgroundStreamingTask.end()
                }
            }
        }
    }

    func handleNameSuggestion(name: String, symbol: String?, conversationId: String) {
        if let conversationId = UUID(uuidString: conversationId) {
            emitEvent?(.renameConversation(conversationId: conversationId, name: name))
            if let symbol {
                emitEvent?(.setConversationSymbol(conversationId: conversationId, symbol: symbol))
            }
        }
    }
}
