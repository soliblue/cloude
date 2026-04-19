import Foundation
import Network
import CloudeShared

extension AppDelegate {
    func setupServices() {
        let token = AuthManager.shared.token
        server = WebSocketServer(port: 8765, authToken: token)
        runnerManager = RunnerManager()

        server.onMessage = { [weak self] message, connection in
            self?.handleMessage(message, from: connection)
        }

        server.onAuthenticate = { [weak self] connection in
            guard let self else { return }
            for (convId, convRunner) in self.runnerManager.activeRunners where convRunner.runner.isRunning {
                self.server.sendMessage(.status(state: .running, conversationId: convId), to: connection)
            }
        }

        runnerManager.onOutput = { [weak self] text, conversationId, seq in
            self?.server.broadcast(.output(text: text, conversationId: conversationId, seq: seq))
        }

        runnerManager.onSessionId = { [weak self] sessionId, conversationId in
            self?.server.broadcast(.sessionId(id: sessionId, conversationId: conversationId))
        }

        runnerManager.onToolCall = { [weak self] name, input, toolId, parentToolId, conversationId, textPosition, editInfo, seq in
            self?.server.broadcast(.toolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, conversationId: conversationId, textPosition: textPosition, editInfo: editInfo, seq: seq))
        }

        runnerManager.onToolResult = { [weak self] toolId, summary, output, conversationId, seq in
            self?.server.broadcast(.toolResult(toolId: toolId, summary: summary, output: output, conversationId: conversationId, seq: seq))
        }

        runnerManager.onRunStats = { [weak self] durationMs, costUsd, model, conversationId, seq in
            self?.server.broadcast(.runStats(durationMs: durationMs, costUsd: costUsd, model: model, conversationId: conversationId, seq: seq))
        }

        runnerManager.onStatusChange = { [weak self] state, conversationId in
            self?.server.broadcast(.status(state: state, conversationId: conversationId))
        }

        runnerManager.onMessageUUID = { [weak self] uuid, conversationId in
            self?.server.broadcast(.messageUUID(uuid: uuid, conversationId: conversationId))
        }
    }
}
