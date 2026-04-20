import Foundation
import CloudeShared

extension EnvironmentConversationRuntime {
    func handleResumeFromResponse(sessionId: String, events: [ReplayedEvent], historyOnly: Bool) {
        AppLogger.connectionInfo("heuristic_counter=resumeFromResponse_receive sessionId=\(sessionId) events=\(events.count) historyOnly=\(historyOnly)")
        if historyOnly {
            if let target = interruptedSessions[sessionId] {
                conversation(for: target.conversationId).output.requiresHistoryResync = true
            }
            return
        }
        if let target = interruptedSessions[sessionId], let messageId = target.messageId {
            emitEvent?(.resumeBegin(conversationId: target.conversationId, messageId: messageId))
        }
        for event in events {
            switch event {
            case .output(let text, let conversationId, let seq):
                handleOutput(text: text, conversationId: conversationId, seq: seq)
            case .toolCall(let name, let input, let toolId, let parentToolId, let conversationId, let textPosition, let editInfo, let seq):
                handleToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, conversationId: conversationId, textPosition: textPosition, editInfo: editInfo, seq: seq)
            case .toolResult(let toolId, _, let output, let conversationId, let seq):
                handleToolResult(toolId: toolId, resultOutput: output, conversationId: conversationId, seq: seq)
            case .runStats(let durationMs, let costUsd, let model, let conversationId, let seq):
                handleRunStats(durationMs: durationMs, costUsd: costUsd, model: model, conversationId: conversationId, seq: seq)
            }
        }
    }

    func handleConnectionLoss() {
        for (conversationId, output) in runningOutputs {
            output.flushBuffer()
            output.completeExecutingTools()
            let snapshot = ConversationOutput()
            snapshot.text = output.text
            snapshot.fullText = output.fullText
            snapshot.toolCalls = output.toolCalls
            snapshot.newSessionId = output.newSessionId
            snapshot.liveMessageId = output.liveMessageId
            emitEvent?(.disconnect(conversationId: conversationId, output: snapshot))
            output.phase = .idle
        }
    }
}
