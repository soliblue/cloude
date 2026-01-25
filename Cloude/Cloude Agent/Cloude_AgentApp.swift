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
    private var server: WebSocketServer!
    private var runner: ClaudeCodeRunner!
    private var popover: NSPopover!

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
            self?.server.broadcast(.output(text: text))
        }

        runner.onComplete = { [weak self] in
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
        case .chat(let text, let workingDirectory):
            server.broadcast(.status(state: .running))
            runner.run(prompt: text, workingDirectory: workingDirectory)

        case .abort:
            runner.abort()

        case .listDirectory(let path):
            handleListDirectory(path, connection: connection)

        case .getFile(let path):
            handleGetFile(path, connection: connection)

        case .auth:
            break // Handled by server
        }
    }

    private func handleListDirectory(_ path: String, connection: NWConnection) {
        switch FileService.shared.listDirectory(at: path) {
        case .success(let entries):
            server.sendMessage(.directoryListing(path: path, entries: entries), to: connection)
        case .failure(let error):
            server.sendMessage(.error(message: error.localizedDescription), to: connection)
        }
    }

    private func handleGetFile(_ path: String, connection: NWConnection) {
        switch FileService.shared.getFile(at: path) {
        case .success(let result):
            let base64 = result.data.base64EncodedString()
            server.sendMessage(.fileContent(path: path, data: base64, mimeType: result.mimeType, size: result.size), to: connection)
        case .failure(let error):
            server.sendMessage(.error(message: error.localizedDescription), to: connection)
        }
    }
}
