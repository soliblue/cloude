import SwiftUI
import CloudeShared

struct ConnectionStatus: View {
    @ObservedObject var connection: ConnectionManager

    var body: some View {
        Button(action: { connection.reconnectAll() }) {
            Circle()
                .fill(statusColor)
                .frame(width: DS.Size.dot, height: DS.Size.dot)
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        if connection.isAuthenticated {
            return connection.isAnyRunning ? .orange : .pastelGreen
        } else if connection.isConnected {
            return .yellow
        }
        return .pastelRed
    }
}
