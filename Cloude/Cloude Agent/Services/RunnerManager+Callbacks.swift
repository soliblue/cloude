import Foundation
import CloudeShared

extension RunnerManager {
    func setupCallbacks(for runner: ClaudeCodeRunner, conversationId: String) {
        runner.onOutput = { [weak self] text in
            guard let self else { return }
            if var convRunner = self.activeRunners[conversationId] {
                convRunner.accumulatedResponse += text
                self.activeRunners[conversationId] = convRunner
            }
            let sessionId = self.activeRunners[conversationId]?.sessionId
            let seq: Int? = sessionId.map { sid in
                self.replayBuffer.stamp(sessionId: sid) { s in
                    .output(text: text, conversationId: conversationId, seq: s)
                }
            }
            self.onOutput?(text, conversationId, seq)
        }

        runner.onSessionId = { [weak self] sessionId in
            guard let self else { return }
            if var convRunner = self.activeRunners[conversationId] {
                convRunner.sessionId = sessionId
                self.activeRunners[conversationId] = convRunner
            }
            self.onSessionId?(sessionId, conversationId)
        }

        runner.onToolCall = { [weak self] name, input, toolId, parentToolId, textPosition, editInfo in
            guard let self else { return }
            if var convRunner = self.activeRunners[conversationId] {
                let storedCall = StoredToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, textPosition: textPosition, editInfo: editInfo)
                convRunner.accumulatedToolCalls.append(storedCall)
                self.activeRunners[conversationId] = convRunner
            }
            let sessionId = self.activeRunners[conversationId]?.sessionId
            let seq: Int? = sessionId.map { sid in
                self.replayBuffer.stamp(sessionId: sid) { s in
                    .toolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, conversationId: conversationId, textPosition: textPosition, editInfo: editInfo, seq: s)
                }
            }
            self.onToolCall?(name, input, toolId, parentToolId, conversationId, textPosition, editInfo, seq)
        }

        runner.onToolResult = { [weak self] toolId, summary, output in
            guard let self else { return }
            let sessionId = self.activeRunners[conversationId]?.sessionId
            let seq: Int? = sessionId.map { sid in
                self.replayBuffer.stamp(sessionId: sid) { s in
                    .toolResult(toolId: toolId, summary: summary, output: output, conversationId: conversationId, seq: s)
                }
            }
            self.onToolResult?(toolId, summary, output, conversationId, seq)
        }

        runner.onRunStats = { [weak self] durationMs, costUsd, model in
            guard let self else { return }
            if var convRunner = self.activeRunners[conversationId] {
                convRunner.runStats = (durationMs, costUsd, model)
                self.activeRunners[conversationId] = convRunner
            }
            let sessionId = self.activeRunners[conversationId]?.sessionId
            let seq: Int? = sessionId.map { sid in
                self.replayBuffer.stamp(sessionId: sid) { s in
                    .runStats(durationMs: durationMs, costUsd: costUsd, model: model, conversationId: conversationId, seq: s)
                }
            }
            self.onRunStats?(durationMs, costUsd, model, conversationId, seq)
        }

        runner.onCloudeCommand = { [weak self] action, value in
            self?.onCloudeCommand?(action, value, conversationId)
        }

        runner.onStatus = { [weak self] state in
            self?.onStatusChange?(state, conversationId)
        }

        runner.onMessageUUID = { [weak self] uuid in
            self?.onMessageUUID?(uuid, conversationId)
        }

        runner.onComplete = { [weak self] in
            guard let self else { return }
            let convRunner = self.activeRunners[conversationId]
            let response = convRunner?.accumulatedResponse ?? ""
            let toolCalls = convRunner?.accumulatedToolCalls ?? []
            let sessionId = convRunner?.sessionId
            let runStats = convRunner?.runStats

            Log.info("Runner for \(conversationId.prefix(8)) complete, response length=\(response.count), toolCalls=\(toolCalls.count)")

            if let sid = sessionId, !response.isEmpty || !toolCalls.isEmpty || runStats != nil {
                ResponseStore.store(sessionId: sid, text: response, toolCalls: toolCalls, durationMs: runStats?.durationMs, costUsd: runStats?.costUsd, model: runStats?.model)
            }

            self.onComplete?(conversationId, sessionId)
            self.onStatusChange?(.idle, conversationId)

            DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
                if let runner = self?.activeRunners[conversationId], !runner.runner.isRunning {
                    if let sid = runner.sessionId {
                        self?.replayBuffer.release(sessionId: sid)
                    }
                    self?.activeRunners.removeValue(forKey: conversationId)
                    Log.info("Cleaned up runner for \(conversationId.prefix(8))")
                }
            }
        }
    }
}
