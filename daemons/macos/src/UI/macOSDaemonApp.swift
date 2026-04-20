import SwiftUI

@main
struct MacOSDaemonApp: App {
    private let server: HTTPServer

    init() {
        _ = DaemonAuth.token
        server = HTTPServer()
        server.start()
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
