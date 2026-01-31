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
                        Log.info("Server listening on port \(self.port)")
                    case .failed(let error):
                        self.isRunning = false
                        self.lastError = error.localizedDescription
                        Log.error("Server failed: \(error)")
                    case .cancelled:
                        self.isRunning = false
                    default:
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
        if token == authToken {
            authenticatedConnections.insert(ObjectIdentifier(connection))
            Log.info("Client authenticated")
            return true
        }
        Log.error("Authentication failed - invalid token")
        return false
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
}
