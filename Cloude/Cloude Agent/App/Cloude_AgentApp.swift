//
//  Cloude_AgentApp.swift
//  Cloude Agent
//
//  Menu bar app that runs WebSocket server for remote Claude Code control
//

import SwiftUI
import Network

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
    private var runner: ClaudeCodeRunner!
    private var popover: NSPopover!
    private var currentSessionId: String?
    private var currentConversationId: String?
    private var accumulatedResponse = ""

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
        runner = ClaudeCodeRunner()

        server.onMessage = { [weak self] message, connection in
            self?.handleMessage(message, from: connection)
        }

        runner.onOutput = { [weak self] text in
            self?.accumulatedResponse += text
            self?.server.broadcast(.output(text: text, conversationId: self?.currentConversationId))
        }

        runner.onSessionId = { [weak self] sessionId in
            self?.currentSessionId = sessionId
            self?.server.broadcast(.sessionId(id: sessionId, conversationId: self?.currentConversationId))
        }

        runner.onToolCall = { [weak self] name, input, toolId, parentToolId in
            self?.server.broadcast(.toolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId, conversationId: self?.currentConversationId))
        }

        runner.onRunStats = { [weak self] durationMs, costUsd in
            self?.server.broadcast(.runStats(durationMs: durationMs, costUsd: costUsd, conversationId: self?.currentConversationId))
        }

        runner.onComplete = { [weak self] in
            let responseLen = self?.accumulatedResponse.count ?? 0
            Log.info("Claude run complete, response length=\(responseLen)")
            if let sessionId = self?.currentSessionId, let response = self?.accumulatedResponse, !response.isEmpty {
                ResponseStore.store(sessionId: sessionId, text: response)
            }
            self?.accumulatedResponse = ""
            self?.server.broadcast(.status(state: .idle, conversationId: self?.currentConversationId))
            self?.currentConversationId = nil
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: StatusView(
            server: server,
            runner: runner,
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
            Log.info("Chat received: \(text.prefix(50))... (len=\(text.count), hasImage=\(imageBase64 != nil), isNew=\(isNewSession))")
            currentConversationId = conversationId
            server.broadcast(.status(state: .running, conversationId: conversationId))
            runner.run(prompt: text, workingDirectory: workingDirectory, sessionId: sessionId, isNewSession: isNewSession, imageBase64: imageBase64)

        case .abort:
            Log.info("Abort requested")
            runner.abort()

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
