import Foundation
import Network
import CloudeShared

extension WebSocketServer {
    func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)
        connectedClients = connections.count

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { @MainActor [self] in
                switch state {
                case .ready:
                    Log.info("Client connected")
                    self.receiveHTTPUpgrade(on: connection)
                case .failed(let error):
                    Log.error("Connection failed: \(error)")
                    self.removeConnection(connection)
                case .cancelled:
                    Log.info("Client disconnected")
                    self.removeConnection(connection)
                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
    }

    func removeConnection(_ connection: NWConnection) {
        connections.removeAll { $0 === connection }
        authenticatedConnections.remove(ObjectIdentifier(connection))
        connectedClients = connections.count
        onDisconnect?(connection)
    }

    func isAuthenticated(_ connection: NWConnection) -> Bool {
        authenticatedConnections.contains(ObjectIdentifier(connection))
    }

    func authenticate(_ connection: NWConnection, token: String) -> Bool {
        let ip = connectionIP(connection)

        if AuthManager.shared.isRateLimited(ip: ip) {
            Log.error("Authentication blocked - rate limited (\(ip))")
            return false
        }

        if token == authToken {
            authenticatedConnections.insert(ObjectIdentifier(connection))
            AuthManager.shared.clearAttempts(for: ip)
            Log.info("Client authenticated")
            return true
        }

        AuthManager.shared.recordFailedAttempt(ip: ip)
        Log.error("Authentication failed - invalid token (\(ip))")
        return false
    }

    private func connectionIP(_ connection: NWConnection) -> String {
        if case .hostPort(let host, _) = connection.endpoint {
            return "\(host)"
        }
        return "unknown"
    }

    func broadcast(_ message: ServerMessage) {
        sendMessage(message)
    }

    func sendMessage(_ message: ServerMessage, to connection: NWConnection? = nil) {
        guard let frame = WebSocketFrame.encode(message) else { return }

        let targets = connection != nil ? [connection!] : connections.filter { authenticatedConnections.contains(ObjectIdentifier($0)) }
        for conn in targets {
            conn.send(content: frame, completion: .contentProcessed { _ in })
        }
    }

    func sendMessage(_ message: ServerMessage, to connection: NWConnection, completion: @escaping () -> Void) {
        guard let frame = WebSocketFrame.encode(message) else {
            completion()
            return
        }

        connection.send(content: frame, completion: .contentProcessed { error in
            if let error = error {
                Log.error("[WebSocket] Send error: \(error)")
            }
            DispatchQueue.main.async {
                completion()
            }
        })
    }
}
