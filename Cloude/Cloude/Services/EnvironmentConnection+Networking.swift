import Foundation
import Combine
import CloudeShared

extension EnvironmentConnection {
    func connect(host: String, port: UInt16, token: String) {
        savedHost = host
        savedPort = port
        savedToken = token
        reconnect()
    }

    func reconnect() {
        guard hasCredentials else { return }
        disconnect(clearCredentials: false)
        connectionToken = UUID()

        let isIP = savedHost.allSatisfy { $0.isNumber || $0 == "." || $0 == ":" }
        let scheme = isIP ? "ws" : "wss"
        guard let url = URL(string: "\(scheme)://\(savedHost):\(savedPort)") else {
            lastError = "Invalid URL"
            return
        }

        session = URLSession(configuration: .default)
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        isConnected = true
        lastError = nil
        manager?.objectWillChange.send()

        receiveMessage(token: connectionToken)
    }

    func reconnectIfNeeded() {
        guard hasCredentials, !isAuthenticated else { return }
        reconnect()
    }

    func disconnect(clearCredentials: Bool = true) {
        connectionToken = UUID()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session = nil
        gitStatusQueue.removeAll()
        gitStatusInFlightPath = nil
        isConnected = false
        isAuthenticated = false
        isWhisperReady = false
        isTranscribing = false
        agentState = .idle

        if clearCredentials {
            savedHost = ""
            savedToken = ""
        }

        manager?.objectWillChange.send()
    }

    func authenticate() {
        send(.auth(token: savedToken))
    }

    func send(_ message: ClientMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return }

        webSocket?.send(.string(text)) { [weak self] error in
            if let error = error {
                Task { @MainActor [weak self] in
                    self?.lastError = error.localizedDescription
                }
            }
        }
    }

    func checkForMissedResponse() {
        if let interrupted = interruptedSession {
            send(.requestMissedResponse(sessionId: interrupted.sessionId))
        }
    }

    func receiveMessage(token: UUID) {
        webSocket?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, token == self.connectionToken else { return }

                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    self.receiveMessage(token: token)

                case .failure(let error):
                    self.lastError = error.localizedDescription
                    self.handleDisconnect()
                }
            }
        }
    }
}
