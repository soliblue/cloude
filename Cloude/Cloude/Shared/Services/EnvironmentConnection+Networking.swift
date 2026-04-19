import Foundation
import Combine
import CloudeShared
import OSLog

extension EnvironmentConnection {
    func connect(host: String, port: UInt16, token: String) {
        AppLogger.connectionInfo("connect envId=\(environmentId.uuidString) host=\(host):\(port)")
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
            AppLogger.connectionError("invalid URL envId=\(environmentId.uuidString) host=\(savedHost) port=\(savedPort)")
            return
        }
        AppLogger.connectionInfo("reconnect envId=\(environmentId.uuidString) url=\(url.absoluteString)")
        AppLogger.beginInterval("environment.auth", key: environmentId.uuidString, details: "url=\(url.absoluteString)")

        session = URLSession(configuration: .default)
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        isConnected = true
        lastError = nil
        manager?.objectWillChange.send()

        receiveMessage(token: connectionToken)
    }

    func reconnectIfNeeded() {
        guard hasCredentials, !isAuthenticated, !isConnected else { return }
        reconnect()
    }

    func disconnect(clearCredentials: Bool = true) {
        AppLogger.connectionInfo("disconnect envId=\(environmentId.uuidString) clearCredentials=\(clearCredentials)")
        connectionToken = UUID()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session = nil
        if let manager, !manager.runningOutputs(for: environmentId).isEmpty {
            handleDisconnect()
        } else {
            gitStatusQueue.removeAll()
            gitStatusInFlightPath = nil
            isConnected = false
            isAuthenticated = false
            isWhisperReady = false
            isTranscribing = false
            agentState = .idle
        }

        if clearCredentials {
            savedHost = ""
            savedToken = ""
        }

        manager?.objectWillChange.send()
    }

    func authenticate() {
        AppLogger.connectionInfo("authenticate envId=\(environmentId.uuidString)")
        send(.auth(token: savedToken))
    }

    func send(_ message: ClientMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return }

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

    func checkForMissedResponse() {
        for (sessionId, target) in interruptedSessions {
            let lastSeenSeq = manager?.output(for: target.conversationId).lastSeenSeq ?? 0
            AppLogger.connectionInfo("heuristic_counter=resumeFrom_send sessionId=\(sessionId) lastSeq=\(lastSeenSeq)")
            send(.resumeFrom(sessionId: sessionId, lastSeq: lastSeenSeq))
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
                    AppLogger.connectionError("receive failed envId=\(self.environmentId.uuidString) error=\(error.localizedDescription)")
                    self.handleDisconnect()
                }
            }
        }
    }
}
