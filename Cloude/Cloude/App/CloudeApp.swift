import SwiftUI

@main
struct CloudeApp: App {
    @StateObject private var connection = ConnectionManager()
    @State private var showSettings = false
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ChatView(connection: connection)
                    .navigationTitle("Cloude")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            ConnectionStatus(connection: connection)
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gear")
                            }
                        }
                    }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(connection: connection)
            }
            .onAppear {
                loadAndConnect()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    connection.reconnectIfNeeded()
                }
            }
        }
    }

    private func loadAndConnect() {
        let host = UserDefaults.standard.string(forKey: "serverHost") ?? ""
        let portString = UserDefaults.standard.string(forKey: "serverPort") ?? "8765"
        let token = KeychainHelper.get(key: "authToken") ?? ""

        guard !host.isEmpty, !token.isEmpty, let port = UInt16(portString) else {
            showSettings = true
            return
        }

        connection.connect(host: host, port: port, token: token)
    }
}

struct ConnectionStatus: View {
    @ObservedObject var connection: ConnectionManager

    var body: some View {
        Button(action: { connection.reconnectIfNeeded() }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        if connection.isAuthenticated {
            return connection.agentState == .running ? .orange : .green
        } else if connection.isConnected {
            return .yellow
        } else {
            return .red
        }
    }

    private var statusText: String {
        if connection.isAuthenticated {
            return connection.agentState == .running ? "Running" : "Connected"
        } else if connection.isConnected {
            return "Connecting..."
        } else {
            return "Disconnected"
        }
    }
}
