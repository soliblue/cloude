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
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupServices()
        setupPopover()
        setupHeartbeat()
        server.start()
        initializeWhisper()
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
        heartbeat.onOutput = { [weak self] text in
            self?.server.broadcast(.heartbeatOutput(text: text))
        }
        heartbeat.onComplete = { [weak self] message in
            self?.server.broadcast(.heartbeatComplete(message: message))
            let config = HeartbeatService.shared.getConfig()
            self?.server.broadcast(.heartbeatConfig(intervalMinutes: config.intervalMinutes, unreadCount: config.unreadCount, sessionId: config.sessionId))
        }
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
            self?.server.broadcast(.toolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, conversationId: conversationId, textPosition: textPosition))
        }

        runnerManager.onRunStats = { [weak self] durationMs, costUsd, conversationId in
            self?.server.broadcast(.runStats(durationMs: durationMs, costUsd: costUsd, conversationId: conversationId))
        }

        runnerManager.onStatusChange = { [weak self] state, conversationId in
            self?.server.broadcast(.status(state: state, conversationId: conversationId))
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
            server.broadcast(.heartbeatConfig(intervalMinutes: config.intervalMinutes, unreadCount: config.unreadCount, sessionId: config.sessionId))

        case .getHeartbeatConfig:
            let config = HeartbeatService.shared.getConfig()
            server.sendMessage(.heartbeatConfig(intervalMinutes: config.intervalMinutes, unreadCount: config.unreadCount, sessionId: config.sessionId), to: connection)

        case .markHeartbeatRead:
            HeartbeatService.shared.markRead()
            let config = HeartbeatService.shared.getConfig()
            server.broadcast(.heartbeatConfig(intervalMinutes: config.intervalMinutes, unreadCount: config.unreadCount, sessionId: config.sessionId))

        case .triggerHeartbeat:
            Log.info("Received triggerHeartbeat request")
            HeartbeatService.shared.triggerNow()

        case .getMemories:
            Log.info("Received getMemories request")
            let sections = MemoryService.parseMemories()
            server.sendMessage(.memories(sections: sections), to: connection)
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
