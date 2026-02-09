import Foundation
import Network
import CryptoKit
import Combine
import CloudeShared

@MainActor
class WebSocketServer: ObservableObject {
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var authenticatedConnections: Set<ObjectIdentifier> = []

    @Published var isRunning = false
    @Published var connectedClients = 0
    @Published var lastError: String?

    let port: UInt16
    private let authToken: String

    var onMessage: ((ClientMessage, NWConnection) -> Void)?

    init(port: UInt16 = 8765, authToken: String) {
        self.port = port
        self.authToken = authToken
    }

    private var startRetryCount = 0
    private let maxStartRetries = 5

    func start() {
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

            listener?.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                Task { @MainActor [self] in
                    switch state {
                    case .ready:
                        self.isRunning = true
                        self.lastError = nil
                        self.startRetryCount = 0
                        Log.startup("Server listening on :\(self.port)")
                    case .failed(let error):
                        self.isRunning = false
                        self.lastError = error.localizedDescription
                        Log.error("Server failed: \(error)")
                        self.retryStartIfNeeded()
                    case .cancelled:
                        self.isRunning = false
                    case .waiting(let error):
                        Log.info("Server waiting: \(error)")
                    case .setup:
                        break
                    @unknown default:
                        break
                    }
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                Task { @MainActor [self] in
                    self.handleNewConnection(connection)
                }
            }

            listener?.start(queue: .main)
        } catch {
            lastError = error.localizedDescription
            Log.error("Failed to start server: \(error)")
            retryStartIfNeeded()
        }
    }

    private func retryStartIfNeeded() {
        guard startRetryCount < maxStartRetries else {
            Log.error("Server failed to start after \(maxStartRetries + 1) attempts, giving up")
            return
        }
        startRetryCount += 1
        let delay = Double(startRetryCount) * 2.0
        Log.startup("  ↻ Retrying server start in \(delay)s (attempt \(startRetryCount + 1)/\(maxStartRetries + 1))...")
        listener?.cancel()
        listener = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.start()
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
        authenticatedConnections.removeAll()
        isRunning = false
        connectedClients = 0
    }

    private func handleNewConnection(_ connection: NWConnection) {
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
