import SwiftUI

@main
struct MacOSDaemonApp: App {
    private let server: HTTPServer

    init() {
        _ = DaemonAuth.token
        SleepPreventionService.shared.applyStoredPreference()
        server = HTTPServer()
        server.start()
        if !UserDefaults.standard.bool(forKey: FolderAccessProbeService.grantedKey) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                FolderAccessProbeService.shared.request()
            }
        }
        Task {
            await RemoteTunnelProvisioner.shared.start()
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            CloudflaredRunner.shared.stop()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image("logo-menubar")
        }
        .menuBarExtraStyle(.window)
    }
}
