import SwiftUI
import Network
import CloudeShared

fileprivate struct QuestionJSON: Codable {
    let q: String
    let options: [AnyCodable]
    let multi: Bool?

    struct AnyCodable: Codable {
        let value: Any

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                value = str
            } else if let dict = try? container.decode([String: String].self) {
                value = dict
            } else {
                value = ""
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            if let str = value as? String {
                try container.encode(str)
            } else if let dict = value as? [String: String] {
                try container.encode(dict)
            }
        }
    }
}

extension QuestionJSON.AnyCodable {
    fileprivate static func ~= (pattern: (Any) -> Bool, value: QuestionJSON.AnyCodable) -> Bool {
        return pattern(value.value)
    }
}

@main
struct Cloude_AgentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    var server: WebSocketServer!
    var runnerManager: RunnerManager!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.rotateIfNeeded()
        Log.logSeparator()
        Log.startup("╔══════════════════════════════════════════════════════════════╗")
        Log.startup("║          CLOUDE AGENT STARTING - \(Date())          ║")
        Log.startup("╚══════════════════════════════════════════════════════════════╝")
        Log.startup("PID: \(ProcessInfo.processInfo.processIdentifier)")
        Log.startup("Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))")
        Log.startup("Bundle: \(Bundle.main.bundlePath)")

        Log.startup("[1/8] Checking for other agents...")
        let killedAgents = ProcessMonitor.killOtherAgents()
        if killedAgents > 0 {
            Log.startup("       Killed \(killedAgents) existing agent process(es), waiting 500ms...")
            Thread.sleep(forTimeInterval: 0.5)
        }
        Log.startup("       ✓ Other agents check complete")

        Log.startup("[2/8] Installing CLI...")
        CLIInstaller.installIfNeeded()
        Log.startup("       ✓ CLI installed")

        Log.startup("[3/8] Setting activation policy...")
        NSApp.setActivationPolicy(.accessory)
        Log.startup("       ✓ Activation policy set to accessory")

        Log.startup("[4/8] Setting up menu bar...")
        setupMenuBar()
        Log.startup("       ✓ Menu bar ready")

        Log.startup("[5/8] Setting up services (WebSocket, RunnerManager)...")
        setupServices()
        Log.startup("       ✓ Services configured")

        Log.startup("[6/8] Setting up popover...")
        setupPopover()
        Log.startup("       ✓ Popover ready")

        Log.startup("[7/8] Setting up heartbeat...")
        setupHeartbeat()
        Log.startup("       ✓ Heartbeat configured")

        Log.startup("[8/8] Starting WebSocket server on port \(server.port)...")
        server.start()
        Log.startup("       Server.start() called - waiting for state update...")

        Log.startup("[POST] Initializing Whisper...")
        initializeWhisper()

        Log.startup("═══════════════════════════════════════════════════════════════")
        Log.startup("STARTUP SEQUENCE COMPLETE - Server should be listening on :\(server.port)")
        Log.startup("Log file: \(Log.logPath)")
        Log.startup("═══════════════════════════════════════════════════════════════")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Log.info("Agent terminating, killing all Claude processes")
        let killed = ProcessMonitor.killAllClaudeProcesses()
        Log.info("Killed \(killed) Claude process(es)")
    }

    private func initializeWhisper() {
        Task {
            WhisperService.shared.onReady = { [weak self] in
                self?.server.broadcast(.whisperReady(ready: true))
            }
            await WhisperService.shared.initialize()
        }
    }

    private func setupHeartbeat() {
        let heartbeat = HeartbeatService.shared
        heartbeat.runnerManager = runnerManager
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: "Cloude")
            button.action = #selector(togglePopover)
        }
    }

    private func setupServices() {
        let token = AuthManager.shared.token
        server = WebSocketServer(port: 8765, authToken: token)
        runnerManager = RunnerManager()

        server.onMessage = { [weak self] message, connection in
            self?.handleMessage(message, from: connection)
        }

        runnerManager.onOutput = { [weak self] text, conversationId in
            self?.server.broadcast(.output(text: text, conversationId: conversationId))
        }

        runnerManager.onSessionId = { [weak self] sessionId, conversationId in
            self?.server.broadcast(.sessionId(id: sessionId, conversationId: conversationId))
        }

        runnerManager.onToolCall = { [weak self] name, input, toolId, parentToolId, conversationId, textPosition in
            if name == "Bash", let cmd = input, cmd.hasPrefix("cloude ") {
                self?.handleCloudeCommand(cmd, conversationId: conversationId)
            }
            self?.server.broadcast(.toolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, conversationId: conversationId, textPosition: textPosition))
        }

        runnerManager.onToolResult = { [weak self] toolId, conversationId in
            self?.server.broadcast(.toolResult(toolId: toolId, conversationId: conversationId))
        }

        runnerManager.onRunStats = { [weak self] durationMs, costUsd, conversationId in
            self?.server.broadcast(.runStats(durationMs: durationMs, costUsd: costUsd, conversationId: conversationId))
        }

        runnerManager.onStatusChange = { [weak self] state, conversationId in
            self?.server.broadcast(.status(state: state, conversationId: conversationId))
        }

        runnerManager.onMessageUUID = { [weak self] uuid, conversationId in
            self?.server.broadcast(.messageUUID(uuid: uuid, conversationId: conversationId))
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

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StatusView(
            server: server,
            runnerManager: runnerManager,
            token: AuthManager.shared.token
        ))
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func handleMessage(_ message: ClientMessage, from connection: NWConnection) {
        switch message {
        case .chat(let text, let workingDirectory, let sessionId, let isNewSession, let imageBase64, let conversationId, let conversationName, let forkSession, let effort):
            Log.info("Chat received: \(text.prefix(50))... (convId=\(conversationId?.prefix(8) ?? "nil"), hasImage=\(imageBase64 != nil), isNew=\(isNewSession), fork=\(forkSession), effort=\(effort ?? "nil"))")
            if let wd = workingDirectory, !wd.isEmpty {
                HeartbeatService.shared.projectDirectory = wd
            }
            let convId = conversationId ?? UUID().uuidString
            runnerManager.run(prompt: text, workingDirectory: workingDirectory, sessionId: sessionId, isNewSession: isNewSession, imageBase64: imageBase64, conversationId: convId, conversationName: conversationName, forkSession: forkSession, effort: effort)

        case .abort(let conversationId):
            if let convId = conversationId {
                Log.info("Abort requested for conversation \(convId.prefix(8))")
                runnerManager.abort(conversationId: convId)
            } else {
                Log.info("Abort all requested")
                runnerManager.abortAll()
            }

        case .listDirectory(let path):
            handleListDirectory(path, connection: connection)

        case .getFile(let path):
            handleGetFile(path, connection: connection)

        case .getFileFullQuality(let path):
            handleGetFile(path, connection: connection, fullQuality: true)

        case .auth:
            break

        case .requestMissedResponse(let sessionId):
            if let stored = ResponseStore.retrieve(sessionId: sessionId) {
                server.sendMessage(.missedResponse(sessionId: sessionId, text: stored.text, completedAt: stored.completedAt, toolCalls: stored.toolCalls), to: connection)
                ResponseStore.clear(sessionId: sessionId)
            } else {
                server.sendMessage(.noMissedResponse(sessionId: sessionId), to: connection)
            }

        case .gitStatus(let path):
            handleGitStatus(path, connection: connection)

        case .gitDiff(let path, let file):
            handleGitDiff(path, file: file, connection: connection)

        case .gitCommit(let path, let message, let files):
            handleGitCommit(path, message: message, files: files, connection: connection)

        case .transcribe(let audioBase64):
            handleTranscribe(audioBase64, connection: connection)

        case .setHeartbeatInterval(let minutes):
            Log.info("setHeartbeatInterval: \(String(describing: minutes))")
            HeartbeatService.shared.setInterval(minutes)
            let config = HeartbeatService.shared.getConfig()
            Log.info("Broadcasting config: interval=\(String(describing: config.intervalMinutes)), unread=\(config.unreadCount)")
            server.broadcast(.heartbeatConfig(intervalMinutes: config.intervalMinutes, unreadCount: config.unreadCount))

        case .getHeartbeatConfig:
            let config = HeartbeatService.shared.getConfig()
            server.sendMessage(.heartbeatConfig(intervalMinutes: config.intervalMinutes, unreadCount: config.unreadCount), to: connection)

        case .markHeartbeatRead:
            HeartbeatService.shared.markRead()
            let config = HeartbeatService.shared.getConfig()
            server.broadcast(.heartbeatConfig(intervalMinutes: config.intervalMinutes, unreadCount: config.unreadCount))

        case .triggerHeartbeat:
            Log.info("Received triggerHeartbeat request")
            HeartbeatService.shared.triggerNow()

        case .getMemories:
            Log.info("Received getMemories request")
            let sections = MemoryService.parseMemories()
            server.sendMessage(.memories(sections: sections), to: connection)

        case .getProcesses:
            let procs = runnerManager.getProcessInfo()
            server.sendMessage(.processList(processes: procs), to: connection)

        case .killProcess(let pid):
            Log.info("Killing process \(pid)")
            _ = ProcessMonitor.killProcess(pid)
            let procs = runnerManager.getProcessInfo()
            server.broadcast(.processList(processes: procs))

        case .killAllProcesses:
            Log.info("Killing all Claude processes")
            _ = ProcessMonitor.killAllClaudeProcesses()
            server.broadcast(.processList(processes: []))

        case .searchFiles(let query, let workingDirectory):
            Log.info("Searching files for '\(query)' in \(workingDirectory)")
            let files = FileSearchService.search(query: query, in: workingDirectory)
            server.sendMessage(.fileSearchResults(files: files, query: query), to: connection)

        case .syncHistory(let sessionId, let workingDirectory):
            Log.info("Syncing history for session \(sessionId.prefix(8)) in \(workingDirectory)")
            let result = HistoryService.getHistory(sessionId: sessionId, workingDirectory: workingDirectory)
            switch result {
            case .success(let messages):
                Log.info("Found \(messages.count) messages")
                server.sendMessage(.historySync(sessionId: sessionId, messages: messages), to: connection)
            case .failure(let error):
                let errorMsg: String
                switch error {
                case .fileNotFound(let path): errorMsg = "Session file not found: \(path)"
                case .readFailed(let msg): errorMsg = "Read failed: \(msg)"
                }
                Log.error("History sync failed: \(errorMsg)")
                server.sendMessage(.historySyncError(sessionId: sessionId, error: errorMsg), to: connection)
            }

        case .listRemoteSessions(let workingDirectory):
            Log.info("Listing remote sessions for \(workingDirectory)")
            let sessions = HistoryService.listSessions(workingDirectory: workingDirectory)
            Log.info("Found \(sessions.count) sessions")
            server.sendMessage(.remoteSessionList(sessions: sessions), to: connection)
        }
    }

    private func handleCloudeCommand(_ command: String, conversationId: String?) {
        let parts = command.dropFirst(7).split(separator: " ", maxSplits: 1).map(String.init)
        guard let action = parts.first else { return }

        switch action {
        case "rename":
            guard let convId = conversationId, parts.count >= 2 else { return }
            let name = parts[1]
            server.broadcast(.renameConversation(conversationId: convId, name: name))
            Log.info("Renamed conversation \(convId.prefix(8)) to '\(name)'")

        case "symbol":
            guard let convId = conversationId else { return }
            let symbol = parts.count >= 2 ? parts[1] : nil
            server.broadcast(.setConversationSymbol(conversationId: convId, symbol: symbol))
            Log.info("Set symbol for \(convId.prefix(8)) to '\(symbol ?? "nil")'")

        case "memory":
            guard parts.count >= 2 else { return }
            let memoryArgs = parts[1].split(separator: " ", maxSplits: 2).map(String.init)
            guard memoryArgs.count >= 3 else {
                Log.info("Memory command requires: cloude memory <local|project> <section> <text>")
                return
            }

            let targetStr = memoryArgs[0].lowercased()
            let section = memoryArgs[1]
            let text = memoryArgs[2]

            let target: MemoryService.MemoryTarget
            switch targetStr {
            case "local": target = .local
            case "project": target = .project
            default:
                Log.info("Unknown memory target: \(targetStr). Use 'local' or 'project'")
                return
            }

            let success = MemoryService.addMemory(target: target, section: section, text: text)
            if success {
                server.broadcast(.memoryAdded(target: targetStr, section: section, text: text, conversationId: conversationId))
            }

        case "skip":
            Log.info("Heartbeat skipped for \(conversationId?.prefix(8) ?? "nil")")
            server.broadcast(.heartbeatSkipped(conversationId: conversationId))

        case "delete":
            guard let convId = conversationId else { return }
            server.broadcast(.deleteConversation(conversationId: convId))
            Log.info("Delete conversation \(convId.prefix(8))")

        case "notify":
            guard parts.count >= 2 else { return }
            let body = parts[1]
            server.broadcast(.notify(title: nil, body: body, conversationId: conversationId))
            Log.info("Notify: \(body.prefix(50))")

        case "clipboard":
            guard parts.count >= 2 else { return }
            let text = parts[1]
            server.broadcast(.clipboard(text: text))
            Log.info("Clipboard: \(text.prefix(50))")

        case "open":
            guard parts.count >= 2 else { return }
            let url = parts[1]
            server.broadcast(.openURL(url: url))
            Log.info("Open URL: \(url)")

        case "haptic":
            let style = parts.count >= 2 ? parts[1] : "medium"
            server.broadcast(.haptic(style: style))
            Log.info("Haptic: \(style)")

        case "speak":
            guard parts.count >= 2 else { return }
            let text = parts[1]
            server.broadcast(.speak(text: text))
            Log.info("Speak: \(text.prefix(50))")

        case "switch":
            guard parts.count >= 2 else { return }
            let targetId = parts[1]
            server.broadcast(.switchConversation(conversationId: targetId))
            Log.info("Switch to conversation: \(targetId.prefix(8))")

        case "ask":
            guard parts.count >= 2 else { return }
            let questions = parseAskCommand(parts[1])
            guard !questions.isEmpty else {
                Log.info("cloude ask: no valid questions parsed")
                return
            }
            server.broadcast(.question(questions: questions, conversationId: conversationId))
            Log.info("Ask: \(questions.count) question(s)")

        default:
            Log.info("Unknown cloude command: \(action)")
        }
    }

    private func parseAskCommand(_ args: String) -> [Question] {
        if args.hasPrefix("--questions ") {
            let jsonStr = String(args.dropFirst(12))
            return parseQuestionsJSON(jsonStr)
        }

        if args.hasPrefix("--q ") {
            return parseSimpleQuestion(args)
        }

        return parseQuestionsJSON(args)
    }

    private func parseQuestionsJSON(_ jsonStr: String) -> [Question] {
        var cleaned = jsonStr.trimmingCharacters(in: .whitespaces)
        if (cleaned.hasPrefix("'") && cleaned.hasSuffix("'")) ||
           (cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"")) {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        guard let data = cleaned.data(using: .utf8) else { return [] }

        do {
            let decoded = try JSONDecoder().decode([QuestionJSON].self, from: data)
            return decoded.map { q in
                let options = q.options.map { opt -> QuestionOption in
                    if let dict = opt.value as? [String: String] {
                        return QuestionOption(
                            label: dict["label"] ?? "",
                            description: dict["desc"] ?? dict["description"]
                        )
                    } else if let str = opt.value as? String {
                        return QuestionOption(label: str)
                    }
                    return QuestionOption(label: String(describing: opt.value))
                }
                return Question(text: q.q, options: options, multiSelect: q.multi ?? false)
            }
        } catch {
            Log.error("Failed to parse questions JSON: \(error)")
            return []
        }
    }

    private func parseSimpleQuestion(_ args: String) -> [Question] {
        var questionText = ""
        var optionsStr = ""
        var multi = false

        let parts = args.components(separatedBy: " --")
        for part in parts {
            let trimmed = part.hasPrefix("-") ? String(part.drop(while: { $0 == "-" })) : part
            if trimmed.hasPrefix("q ") {
                questionText = String(trimmed.dropFirst(2)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            } else if trimmed.hasPrefix("options ") {
                optionsStr = String(trimmed.dropFirst(8)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            } else if trimmed == "multi" {
                multi = true
            }
        }

        guard !questionText.isEmpty, !optionsStr.isEmpty else { return [] }

        let options = optionsStr.split(separator: ",").map { optStr -> QuestionOption in
            let parts = optStr.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                return QuestionOption(label: String(parts[0]), description: String(parts[1]))
            }
            return QuestionOption(label: String(optStr))
        }

        return [Question(text: questionText, options: options, multiSelect: multi)]
    }

    private func handleTranscribe(_ audioBase64: String, connection: NWConnection) {
        Log.info("Transcribe: received \(audioBase64.count) chars")
        Task {
            do {
                let text = try await WhisperService.shared.transcribe(audioBase64: audioBase64)
                Log.info("Transcribe: result '\(text.prefix(50))...'")
                await MainActor.run {
                    server.sendMessage(.transcription(text: text), to: connection)
                }
            } catch {
                Log.error("Transcribe failed: \(error.localizedDescription)")
                await MainActor.run {
                    server.sendMessage(.error(message: "Transcription failed: \(error.localizedDescription)"), to: connection)
                }
            }
        }
    }
}
