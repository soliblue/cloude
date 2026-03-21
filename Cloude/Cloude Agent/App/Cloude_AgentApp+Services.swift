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

        server.onDisconnect = { [weak self] connection in
            self?.cleanupTerminal(for: connection)
        }

        runnerManager.onOutput = { [weak self] text, conversationId in
            self?.server.broadcast(.output(text: text, conversationId: conversationId))
        }

        runnerManager.onSessionId = { [weak self] sessionId, conversationId in
            self?.server.broadcast(.sessionId(id: sessionId, conversationId: conversationId))
        }

        runnerManager.onToolCall = { [weak self] name, input, toolId, parentToolId, conversationId, textPosition, editInfo in
            self?.server.broadcast(.toolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, conversationId: conversationId, textPosition: textPosition, editInfo: editInfo))
        }

        runnerManager.onToolResult = { [weak self] toolId, summary, output, conversationId in
            self?.server.broadcast(.toolResult(toolId: toolId, summary: summary, output: output, conversationId: conversationId))
        }

        runnerManager.onRunStats = { [weak self] durationMs, costUsd, model, conversationId in
            self?.server.broadcast(.runStats(durationMs: durationMs, costUsd: costUsd, model: model, conversationId: conversationId))
        }

        runnerManager.onStatusChange = { [weak self] state, conversationId in
            self?.server.broadcast(.status(state: state, conversationId: conversationId))
        }

        runnerManager.onMessageUUID = { [weak self] uuid, conversationId in
            self?.server.broadcast(.messageUUID(uuid: uuid, conversationId: conversationId))
        }

        runnerManager.onTeamCreated = { [weak self] teamName, leadAgentId, conversationId in
            self?.server.broadcast(.teamCreated(teamName: teamName, leadAgentId: leadAgentId, conversationId: conversationId))
        }

        runnerManager.onTeammateSpawned = { [weak self] teammate, conversationId in
            self?.server.broadcast(.teammateSpawned(teammate: teammate, conversationId: conversationId))
        }

        runnerManager.onTeamDeleted = { [weak self] conversationId in
            self?.server.broadcast(.teamDeleted(conversationId: conversationId))
        }

        runnerManager.onTeammateInboxUpdate = { [weak self] teammateId, status, lastMessage, lastMessageAt, conversationId in
            self?.server.broadcast(.teammateUpdate(teammateId: teammateId, status: status, lastMessage: lastMessage, lastMessageAt: lastMessageAt, conversationId: conversationId))
        }

        runnerManager.onComplete = { [weak self] conversationId, _ in
            if conversationId == Heartbeat.sessionId {
                let runner = self?.runnerManager.activeRunners[conversationId]
                let response = runner?.accumulatedResponse ?? ""
                let isEmpty = response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              response == "<skip>" ||
                              response == "."
                HeartbeatService.shared.handleComplete(isEmpty: isEmpty)
                let config = HeartbeatService.shared.getConfig()
                self?.server.broadcast(.heartbeatConfig(intervalMinutes: config.intervalMinutes, unreadCount: config.unreadCount))
            }
        }
    }
}
