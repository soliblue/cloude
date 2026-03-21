import Foundation
import Combine
import CloudeShared

struct ConversationRunner {
    let runner: ClaudeCodeRunner
    let conversationId: String
    var conversationName: String?
    var accumulatedResponse: String = ""
    var accumulatedToolCalls: [StoredToolCall] = []
    var sessionId: String?
}

struct ActiveTeam {
    let teamName: String
    var teammates: [String: TeammateInfo] = [:]
    var lastInboxState: [String: Int] = [:]
}

@MainActor
class RunnerManager: ObservableObject {
    @Published var activeRunners: [String: ConversationRunner] = [:]

    var onOutput: ((String, String) -> Void)?
    var onSessionId: ((String, String) -> Void)?
    var onToolCall: ((String, String?, String, String?, String, Int?, EditInfo?) -> Void)?
    var onToolResult: ((String, String?, String?, String) -> Void)?
    var onRunStats: ((Int, Double, String?, String) -> Void)?
    var onComplete: ((String, String?) -> Void)?
    var onStatusChange: ((AgentState, String) -> Void)?
    var onCloudeCommand: ((String, String, String) -> Void)?
    var onMessageUUID: ((String, String) -> Void)?
    var onTeamCreated: ((String, String, String) -> Void)?
    var onTeammateSpawned: ((TeammateInfo, String) -> Void)?
    var onTeamDeleted: ((String) -> Void)?

    var inboxTimers: [String: Timer] = [:]
    var activeTeams: [String: ActiveTeam] = [:]
    var _onTeammateInboxUpdate: ((String, TeammateStatus?, String?, Date?, String) -> Void)?

    var isAnyRunning: Bool {
        activeRunners.values.contains { $0.runner.isRunning }
    }

    var runningCount: Int {
        activeRunners.values.filter { $0.runner.isRunning }.count
    }

    func getProcessInfo() -> [AgentProcessInfo] {
        let systemProcs = ProcessMonitor.findClaudeProcesses()
        return systemProcs.map { proc in
            let matchingRunner = activeRunners.values.first { runner in
                runner.runner.process?.processIdentifier == proc.id
            }
            return AgentProcessInfo(
                pid: proc.id,
                command: proc.command,
                startTime: proc.startTime,
                conversationId: matchingRunner?.conversationId,
                conversationName: matchingRunner?.conversationName
            )
        }
    }

    func run(prompt: String, workingDirectory: String?, sessionId: String?, isNewSession: Bool, imagesBase64: [String]?, filesBase64: [AttachedFilePayload]? = nil, conversationId: String, conversationName: String? = nil, useFixedSessionId: Bool = false, forkSession: Bool = false, model: String? = nil, effort: String? = nil) {
        if let existing = activeRunners[conversationId], existing.runner.isRunning {
            Log.info("Runner for \(conversationId.prefix(8)) already running, aborting old one")
            existing.runner.abort()
        }

        let runner = ClaudeCodeRunner()
        var convRunner = ConversationRunner(runner: runner, conversationId: conversationId, conversationName: conversationName)
        convRunner.sessionId = sessionId

        setupCallbacks(for: runner, conversationId: conversationId)

        activeRunners[conversationId] = convRunner
        onStatusChange?(.running, conversationId)

        Log.info("Starting runner for conversation \(conversationId.prefix(8))... (fork=\(forkSession), model=\(model ?? "default"), effort=\(effort ?? "nil"))")
        runner.run(prompt: prompt, workingDirectory: workingDirectory, sessionId: sessionId, isNewSession: isNewSession, imagesBase64: imagesBase64, filesBase64: filesBase64, useFixedSessionId: useFixedSessionId, forkSession: forkSession, model: model, effort: effort)
    }

    func abort(conversationId: String) {
        guard let convRunner = activeRunners[conversationId] else {
            Log.info("No runner found for \(conversationId.prefix(8)) to abort, broadcasting idle")
            onStatusChange?(.idle, conversationId)
            return
        }
        Log.info("Aborting runner for \(conversationId.prefix(8))")
        convRunner.runner.abort()
    }

    func abortAll() {
        for (convId, convRunner) in activeRunners where convRunner.runner.isRunning {
            Log.info("Aborting runner for \(convId.prefix(8))")
            convRunner.runner.abort()
        }
    }
}
