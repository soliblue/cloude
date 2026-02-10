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
    var onToolCall: ((String, String?, String, String?, String, Int?) -> Void)?
    var onToolResult: ((String, String?, String?, String) -> Void)?
    var onRunStats: ((Int, Double, String?, String) -> Void)?
    var onComplete: ((String, String?) -> Void)?
    var onStatusChange: ((AgentState, String) -> Void)?
    var onCloudeCommand: ((String, String, String) -> Void)?
    var onMessageUUID: ((String, String) -> Void)?
    var onTeamCreated: ((String, String, String) -> Void)?
    var onTeammateSpawned: ((TeammateInfo, String) -> Void)?
    var onTeamDeleted: ((String) -> Void)?

    private var inboxTimers: [String: Timer] = [:]
    private var activeTeams: [String: ActiveTeam] = [:]

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

    private func setupCallbacks(for runner: ClaudeCodeRunner, conversationId: String) {
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

        runner.onToolCall = { [weak self] name, input, toolId, parentToolId, textPosition in
            guard let self else { return }
            if var convRunner = self.activeRunners[conversationId] {
                let storedCall = StoredToolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, textPosition: textPosition)
                convRunner.accumulatedToolCalls.append(storedCall)
                self.activeRunners[conversationId] = convRunner
            }
            self.onToolCall?(name, input, toolId, parentToolId, conversationId, textPosition)
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

    var onTeammateInboxUpdate: ((String, TeammateStatus?, String?, Date?, String) -> Void)?

    private func startInboxPolling(conversationId: String, teamName: String) {
        stopInboxPolling(conversationId: conversationId)
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollInbox(conversationId: conversationId, teamName: teamName)
            }
        }
        inboxTimers[conversationId] = timer
    }

    private func stopInboxPolling(conversationId: String) {
        inboxTimers[conversationId]?.invalidate()
        inboxTimers.removeValue(forKey: conversationId)
    }

    private func pollInbox(conversationId: String, teamName: String) {
        let teamsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/teams/\(teamName)/inboxes")
        let leadInbox = teamsDir.appendingPathComponent("team-lead.json")

        guard let data = try? Data(contentsOf: leadInbox),
              let messages = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

        let currentCount = messages.count
        let lastCount = activeTeams[conversationId]?.lastInboxState["team-lead"] ?? 0
        guard currentCount > lastCount else { return }
        activeTeams[conversationId]?.lastInboxState["team-lead"] = currentCount

        for i in lastCount..<currentCount {
            let msg = messages[i]
            guard let from = msg["from"] as? String,
                  let text = msg["text"] as? String else { continue }

            let summary = msg["summary"] as? String
            let color = msg["color"] as? String
            let timestampStr = msg["timestamp"] as? String

            let timestamp: Date
            if let ts = timestampStr {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                timestamp = formatter.date(from: ts) ?? Date()
            } else {
                timestamp = Date()
            }

            if text.contains("\"type\":\"idle_notification\"") {
                let teammateId = findTeammateId(named: from, conversationId: conversationId)
                onTeammateInboxUpdate?(teammateId, .idle, nil, nil, conversationId)
            } else if text.contains("\"type\":\"shutdown_approved\"") {
                let teammateId = findTeammateId(named: from, conversationId: conversationId)
                onTeammateInboxUpdate?(teammateId, .shutdown, nil, nil, conversationId)
            } else {
                let teammateId = findTeammateId(named: from, conversationId: conversationId)
                let displayText = summary ?? String(text.prefix(100))
                onTeammateInboxUpdate?(teammateId, .working, displayText, timestamp, conversationId)
            }
        }
    }

    private func findTeammateId(named name: String, conversationId: String) -> String {
        if let teammates = activeTeams[conversationId]?.teammates {
            for (id, info) in teammates where info.name == name {
                return id
            }
        }
        return name
    }
}
