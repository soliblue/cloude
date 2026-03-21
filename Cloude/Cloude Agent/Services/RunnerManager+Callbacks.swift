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
            self.onOutput?(text, conversationId)
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
            self.onToolCall?(name, input, toolId, parentToolId, conversationId, textPosition, editInfo)
        }

        runner.onToolResult = { [weak self] toolId, summary, output in
            self?.onToolResult?(toolId, summary, output, conversationId)
        }

        runner.onRunStats = { [weak self] durationMs, costUsd, model in
            self?.onRunStats?(durationMs, costUsd, model, conversationId)
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

        runner.onTeamCreated = { [weak self] teamName, leadAgentId in
            guard let self else { return }
            self.activeTeams[conversationId] = ActiveTeam(teamName: teamName)
            self.startInboxPolling(conversationId: conversationId, teamName: teamName)
            self.onTeamCreated?(teamName, leadAgentId, conversationId)
        }

        runner.onTeammateSpawned = { [weak self] teammate in
            guard let self else { return }
            self.activeTeams[conversationId]?.teammates[teammate.id] = teammate
            self.onTeammateSpawned?(teammate, conversationId)
        }

        runner.onTeamDeleted = { [weak self] in
            guard let self else { return }
            self.stopInboxPolling(conversationId: conversationId)
            self.activeTeams.removeValue(forKey: conversationId)
            self.onTeamDeleted?(conversationId)
        }

        runner.onComplete = { [weak self] in
            guard let self else { return }
            let convRunner = self.activeRunners[conversationId]
            let response = convRunner?.accumulatedResponse ?? ""
            let toolCalls = convRunner?.accumulatedToolCalls ?? []
            let sessionId = convRunner?.sessionId

            Log.info("Runner for \(conversationId.prefix(8)) complete, response length=\(response.count), toolCalls=\(toolCalls.count)")

            if let sid = sessionId, !response.isEmpty {
                ResponseStore.store(sessionId: sid, text: response, toolCalls: toolCalls)
            }

            self.onComplete?(conversationId, sessionId)
            self.onStatusChange?(.idle, conversationId)

            self.stopInboxPolling(conversationId: conversationId)
            self.activeTeams.removeValue(forKey: conversationId)

            DispatchQueue.main.asyncAfter(deadline: .now() + 300) { [weak self] in
                if let runner = self?.activeRunners[conversationId], !runner.runner.isRunning {
                    self?.activeRunners.removeValue(forKey: conversationId)
                    Log.info("Cleaned up runner for \(conversationId.prefix(8))")
                }
            }
        }
    }
}
