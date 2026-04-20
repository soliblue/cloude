import Foundation
import CloudeShared

extension Connection {
    func connect(host: String, port: UInt16, token: String) {
        AppLogger.connectionInfo("connect envId=\(environmentId.uuidString) host=\(host):\(port)")
        savedHost = host
        savedPort = port
        savedToken = token
        reconnect()
    }

    func reconnect() {
        if hasCredentials {
            disconnect(clearCredentials: false)
            connectionToken = UUID()

            let isIP = savedHost.allSatisfy { $0.isNumber || $0 == "." || $0 == ":" }
            let scheme = isIP ? "ws" : "wss"
            if let url = URL(string: "\(scheme)://\(savedHost):\(savedPort)") {
                AppLogger.connectionInfo("reconnect envId=\(environmentId.uuidString) url=\(url.absoluteString)")
                AppLogger.beginInterval("environment.auth", key: environmentId.uuidString, details: "url=\(url.absoluteString)")

                session = URLSession(configuration: .default)
                webSocket = session?.webSocketTask(with: url)
                webSocket?.resume()

                phase = .connected
                lastError = nil

                receiveMessage(token: connectionToken)
            } else {
                lastError = "Invalid URL"
                AppLogger.connectionError("invalid URL envId=\(environmentId.uuidString) host=\(savedHost) port=\(savedPort)")
            }
        }
    }

    func reconnectIfNeeded() {
        if hasCredentials, phase == .disconnected {
            reconnect()
        }
    }

    func disconnect(clearCredentials: Bool = true) {
        AppLogger.connectionInfo("disconnect envId=\(environmentId.uuidString) clearCredentials=\(clearCredentials)")
        connectionToken = UUID()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session = nil
        handleDisconnect()

        if clearCredentials {
            savedHost = ""
            savedToken = ""
        }
    }

    func authenticate() {
        AppLogger.connectionInfo("authenticate envId=\(environmentId.uuidString)")
        send(.auth(token: savedToken))
    }

    func resumeInterruptedSessions() {
        conversationRuntime.resumeInterruptedSessions()
    }

    func receiveMessage(token: UUID) {
        webSocket?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                if let self, token == self.connectionToken {
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
                        AppLogger.connectionError("receive failed envId=\(self.environmentId.uuidString) error=\(error.localizedDescription)")
                        self.handleDisconnect()
                    }
                }
            }
        }
    }

    func send(_ message: ClientMessage) {
        if let data = try? JSONEncoder().encode(message),
           let text = String(data: data, encoding: .utf8) {
            webSocket?.send(.string(text)) { [weak self] error in
                if let error = error {
                    Task { @MainActor [weak self] in
                        self?.lastError = error.localizedDescription
                        if let self {
                            AppLogger.connectionError("send failed envId=\(self.environmentId.uuidString) error=\(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}
