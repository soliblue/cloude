import Foundation
import Network
import CryptoKit
import Combine
import CloudeShared

@MainActor
class WebSocketServer: ObservableObject {
    var listener: NWListener?
    var connections: [NWConnection] = []
    var authenticatedConnections: Set<ObjectIdentifier> = []

    @Published var isRunning = false
    @Published var connectedClients = 0
    @Published var lastError: String?

    let port: UInt16
    let authToken: String

    var onMessage: ((ClientMessage, NWConnection) -> Void)?
    var onDisconnect: ((NWConnection) -> Void)?

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
}
