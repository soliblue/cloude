import Foundation
import Combine
import CloudeShared

@MainActor
final class ConnectionStore: ObservableObject {
    @Published var connections: [UUID: Connection] = [:]
    let events = PassthroughSubject<ConnectionEvent, Never>()

    func connection(for environmentId: UUID?) -> Connection? {
        environmentId.flatMap { connections[$0] }
    }

    func connectEnvironment(_ envId: UUID, host: String, port: UInt16, token: String, symbol: String = "laptopcomputer") {
        AppLogger.connectionInfo("connectEnvironment envId=\(envId.uuidString) host=\(host):\(port)")
        let connection = connections[envId] ?? Connection(environmentId: envId)
        connection.connectionStore = self
        connection.symbol = symbol
        connections[envId] = connection
        connection.connect(host: host, port: port, token: token)
    }

    func disconnectEnvironment(_ envId: UUID, clearCredentials: Bool = true) {
        connections[envId]?.disconnect(clearCredentials: clearCredentials)
    }

    func removeConnection(_ envId: UUID) {
        if let connection = connections.removeValue(forKey: envId) {
            connection.disconnect()
        }
    }

    func reconnectAll() {
        for connection in connections.values {
            connection.reconnectIfNeeded()
        }
    }
}
