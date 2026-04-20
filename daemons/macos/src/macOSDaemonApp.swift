import SwiftUI

@main
struct MacOSDaemonApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        Text("Daemon for Remote CC")
            .padding()
            .frame(minWidth: 280, minHeight: 120)
    }
}
