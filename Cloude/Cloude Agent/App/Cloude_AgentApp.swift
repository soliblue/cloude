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
    let autocompleteService = AutocompleteService()
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.rotateIfNeeded()
        Log.logSeparator()

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        Log.startup("Cloude Agent \(version) (\(build)) — PID \(ProcessInfo.processInfo.processIdentifier)")

        let killedAgents = ProcessMonitor.killOtherAgents()
        if killedAgents > 0 {
            Log.startup("Killed \(killedAgents) existing agent(s), waiting 2s...")
            Thread.sleep(forTimeInterval: 2.0)
        }

        CLIInstaller.installIfNeeded()
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupServices()
        installSignalHandlers()
        setupPopover()
        setupHeartbeat()

        if let portOwner = ProcessMonitor.checkPortOwner(server.port) {
            Log.startup("⚠️ Port \(server.port) in use: \(portOwner)")
        }
        server.start()

        initializeWhisper()
        initializeKokoro()

        Log.startup("Ready on :\(server.port) — log: \(Log.logPath)")
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

    private func initializeKokoro() {
        Task {
            KokoroService.shared.onReady = { [weak self] in
                self?.server.broadcast(.kokoroReady(ready: true))
            }
            await KokoroService.shared.initialize()
        }
    }

    func handleSynthesize(_ text: String, messageId: String, voice: String?, connection: NWConnection) {
        Log.info("Synthesize: \(text.count) chars for message \(messageId.prefix(8)) voice=\(voice ?? "default")")
        Task {
            do {
                let wavData = try await KokoroService.shared.synthesize(text: text, voice: voice)
                let base64 = wavData.base64EncodedString()
                Log.info("Synthesize: generated \(wavData.count) bytes WAV")
                await MainActor.run {
                    server.sendMessage(.ttsAudio(audioBase64: base64, messageId: messageId), to: connection)
                }
            } catch {
                Log.error("Synthesize failed: \(error.localizedDescription)")
                await MainActor.run {
                    server.sendMessage(.error(message: "TTS failed: \(error.localizedDescription)"), to: connection)
                }
            }
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

        runnerManager.onToolResult = { [weak self] toolId, summary, output, conversationId in
            self?.server.broadcast(.toolResult(toolId: toolId, summary: summary, output: output, conversationId: conversationId))
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

    private func installSignalHandlers() {
        let signalCallback: @convention(c) (Int32) -> Void = { sig in
            let sigName = sig == SIGTERM ? "SIGTERM" : "SIGINT"
            Log.info("Received \(sigName), shutting down gracefully...")
            DispatchQueue.main.async {
                guard let delegate = NSApp.delegate as? AppDelegate else {
                    exit(0)
                }
                delegate.server.stop()
                Log.info("Server stopped, killing Claude processes...")
                let killed = ProcessMonitor.killAllClaudeProcesses()
                Log.info("Killed \(killed) Claude process(es), exiting")
                exit(0)
            }
        }
        signal(SIGTERM, signalCallback)
        signal(SIGINT, signalCallback)
    }

    static func codeSigningIdentity() -> String {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dvv", Bundle.main.bundlePath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let authority = output.components(separatedBy: "\n")
                .first { $0.hasPrefix("Authority=") }?
                .replacingOccurrences(of: "Authority=", with: "") ?? "unknown"
            let teamId = output.components(separatedBy: "\n")
                .first { $0.hasPrefix("TeamIdentifier=") }?
                .replacingOccurrences(of: "TeamIdentifier=", with: "") ?? "unknown"
            return "\(authority) (Team: \(teamId))"
        } catch {
            return "failed to read: \(error.localizedDescription)"
        }
    }

    func handleTranscribe(_ audioBase64: String, connection: NWConnection) {
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
