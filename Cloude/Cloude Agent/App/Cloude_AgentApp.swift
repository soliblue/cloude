import SwiftUI
import Network
import CloudeShared

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
        Log.info("Agent starting up")

        let killedAgents = ProcessMonitor.killOtherAgents()
        if killedAgents > 0 {
            Log.info("Killed \(killedAgents) existing agent process(es)")
            Thread.sleep(forTimeInterval: 0.5)
        }

        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupServices()
        setupPopover()
        setupHeartbeat()
        server.start()
        initializeWhisper()
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

        runnerManager.onRunStats = { [weak self] durationMs, costUsd, conversationId in
            self?.server.broadcast(.runStats(durationMs: durationMs, costUsd: costUsd, conversationId: conversationId))
        }

        runnerManager.onStatusChange = { [weak self] state, conversationId in
            self?.server.broadcast(.status(state: state, conversationId: conversationId))
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
        case .chat(let text, let workingDirectory, let sessionId, let isNewSession, let imageBase64, let conversationId):
            Log.info("Chat received: \(text.prefix(50))... (convId=\(conversationId?.prefix(8) ?? "nil"), hasImage=\(imageBase64 != nil), isNew=\(isNewSession))")
            if let wd = workingDirectory, !wd.isEmpty {
                HeartbeatService.shared.projectDirectory = wd
            }
            let convId = conversationId ?? UUID().uuidString
            runnerManager.run(prompt: text, workingDirectory: workingDirectory, sessionId: sessionId, isNewSession: isNewSession, imageBase64: imageBase64, conversationId: convId)

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

        case .auth:
            break

        case .requestMissedResponse(let sessionId):
            if let stored = ResponseStore.retrieve(sessionId: sessionId) {
                server.sendMessage(.missedResponse(sessionId: sessionId, text: stored.text, completedAt: stored.completedAt), to: connection)
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
            let procs = ProcessMonitor.findClaudeProcesses().map { AgentProcessInfo(pid: $0.id, command: $0.command, startTime: $0.startTime) }
            server.sendMessage(.processList(processes: procs), to: connection)

        case .killProcess(let pid):
            Log.info("Killing process \(pid)")
            _ = ProcessMonitor.killProcess(pid)
            let procs = ProcessMonitor.findClaudeProcesses().map { AgentProcessInfo(pid: $0.id, command: $0.command, startTime: $0.startTime) }
            server.broadcast(.processList(processes: procs))

        case .killAllProcesses:
            Log.info("Killing all Claude processes")
            _ = ProcessMonitor.killAllClaudeProcesses()
            server.broadcast(.processList(processes: []))
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

        default:
            Log.info("Unknown cloude command: \(action)")
        }
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
