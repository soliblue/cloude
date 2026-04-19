import Combine
import Foundation
import CloudeShared

extension EnvironmentConnection {
    func handleOutput(_ mgr: EnvironmentStore, text: String, conversationId: String?, seq: Int? = nil) {
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            if let seq, seq <= output(for: convId).lastSeenSeq { return }
            AppLogger.connectionInfo("assistant output convId=\(convId.uuidString) chars=\(text.count) seq=\(seq.map(String.init) ?? "nil")")
            AppLogger.endInterval("chat.firstToken", key: convId.uuidString)
            let out = output(for: convId)
            out.completeExecutingTools(topLevelOnly: true)
            out.appendText(text)
            ensureRunning(out)
            if let seq { out.lastSeenSeq = max(out.lastSeenSeq, seq) }
        }
    }

    func handleToolCall(_ mgr: EnvironmentStore, name: String, input: String?, toolId: String, parentToolId: String?, conversationId: String?, textPosition: Int?, editInfo: EditInfo? = nil, seq: Int? = nil) {
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("tool call convId=\(convId.uuidString) toolId=\(toolId) name=\(name) seq=\(seq.map(String.init) ?? "nil")")
            let out = output(for: convId)
            ensureRunning(out)
            if parentToolId == nil {
                out.completeExecutingTools(topLevelOnly: true)
            }
            let currentTextLength = out.fullText.count
            let position = min(textPosition ?? currentTextLength, currentTextLength)
            out.toolCalls.append(ToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, textPosition: position, state: .executing, editInfo: editInfo))
            mgr.events.send(.liveSnapshot(conversationId: convId))
            if let seq { out.lastSeenSeq = max(out.lastSeenSeq, seq) }
        }
    }

    func handleToolResult(_ mgr: EnvironmentStore, toolId: String, output: String?, conversationId: String?, seq: Int? = nil) {
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("tool result convId=\(convId.uuidString) toolId=\(toolId) outputChars=\(output?.count ?? 0) seq=\(seq.map(String.init) ?? "nil")")
            let out = self.output(for: convId)
            if !out.toolCalls.contains(where: { $0.toolId == toolId }) {
                AppLogger.connectionInfo("heuristic_counter=requiresHistoryResync_flip reason=tool_result_without_call convId=\(convId.uuidString) toolId=\(toolId)")
                out.requiresHistoryResync = true
            }
            out.toolCalls = out.toolCalls.map { tool in
                if tool.toolId == toolId {
                    var updated = tool
                    updated.state = .complete
                    updated.resultOutput = output
                    return updated
                }
                return tool
            }
            if let seq { out.lastSeenSeq = max(out.lastSeenSeq, seq) }
        }
    }

    func handleRunStats(_ mgr: EnvironmentStore, durationMs: Int, costUsd: Double, model: String?, conversationId: String?, seq: Int? = nil) {
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("run stats convId=\(convId.uuidString) durationMs=\(durationMs) costUsd=\(costUsd) seq=\(seq.map(String.init) ?? "nil")")
            AppLogger.endInterval("chat.complete", key: convId.uuidString, details: "serverDurationMs=\(durationMs) costUsd=\(costUsd)")
            let out = output(for: convId)
            out.runStats = RunStats(durationMs: durationMs, costUsd: costUsd, model: model)
            if let seq { out.lastSeenSeq = max(out.lastSeenSeq, seq) }
        }
    }

    func handleSessionId(_ mgr: EnvironmentStore, _ id: String, conversationId: String?) {
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("session id convId=\(convId.uuidString) sessionId=\(id)")
            output(for: convId).newSessionId = id
            mgr.events.send(.sessionIdReceived(conversationId: convId, sessionId: id))
        }
    }

    func handleMessageUUID(_ mgr: EnvironmentStore, _ uuid: String, conversationId: String?) {
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("message uuid convId=\(convId.uuidString) uuid=\(uuid)")
            output(for: convId).messageUUID = uuid
        }
    }

    func handleStatus(_ mgr: EnvironmentStore, state: AgentState, conversationId: String?) {
        if agentState != state { agentState = state }
        if let convId = conversationId.flatMap({ UUID(uuidString: $0) }) {
            AppLogger.connectionInfo("status convId=\(convId.uuidString) state=\(state.rawValue)")
            let out = output(for: convId)
            if state == .idle {
                out.flushBuffer()
                out.completeExecutingTools()
                AppLogger.cancelInterval("chat.firstToken", key: convId.uuidString, reason: "idle")
                AppLogger.cancelInterval("chat.complete", key: convId.uuidString, reason: "idle")
                if let stats = out.runStats, stats.costUsd > 0 {
                    mgr.events.send(.lastAssistantMessageCostUpdate(conversationId: convId, costUsd: stats.costUsd))
                }
            }
            let oldPhase = out.phase
            out.phase = (state == .running) ? .running : (state == .compacting ? .compacting : .idle)
            if oldPhase == .idle && out.phase != .idle {
                mgr.events.send(.reconnectRunning(conversationId: convId))
            }
            if state == .idle {
                if oldPhase != .idle { mgr.events.send(.turnCompleted(conversationId: convId)) }
                let anyRunning = conversationOutputs.values.contains { $0.phase != .idle }
                if !anyRunning { BackgroundStreamingTask.end() }
            }
        }
    }
}
