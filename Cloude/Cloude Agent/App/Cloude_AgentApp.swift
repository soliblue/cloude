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

}
