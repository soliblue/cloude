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
    private var accumulatedResponse = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupServices()
        setupPopover()
        server.start()
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
            self?.server.broadcast(.output(text: text))
        }

        runner.onSessionId = { [weak self] sessionId in
            self?.currentSessionId = sessionId
            self?.server.broadcast(.sessionId(id: sessionId))
        }

        runner.onToolCall = { [weak self] name, input, toolId, parentToolId in
            self?.server.broadcast(.toolCall(name: name, input: input, toolId: toolId, parentToolId: parentToolId))
        }

        runner.onRunStats = { [weak self] durationMs, costUsd in
            self?.server.broadcast(.runStats(durationMs: durationMs, costUsd: costUsd))
        }

        runner.onComplete = { [weak self] in
            if let sessionId = self?.currentSessionId, let response = self?.accumulatedResponse, !response.isEmpty {
                ResponseStore.store(sessionId: sessionId, text: response)
            }
            self?.accumulatedResponse = ""
            self?.server.broadcast(.status(state: .idle))
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
        case .chat(let text, let workingDirectory, let sessionId, let isNewSession, let imageBase64):
            server.broadcast(.status(state: .running))
            runner.run(prompt: text, workingDirectory: workingDirectory, sessionId: sessionId, isNewSession: isNewSession, imageBase64: imageBase64)

        case .abort:
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
        }
    }

}
