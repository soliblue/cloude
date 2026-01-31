import SwiftUI
import CloudeShared

struct ConnectionStatus: View {
    @ObservedObject var connection: ConnectionManager

    var body: some View {
        Button(action: { connection.reconnectIfNeeded() }) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        if connection.isAuthenticated {
            return connection.isAnyRunning ? .orange : .green
        } else if connection.isConnected {
            return .yellow
        }
        return .red
    }
}
