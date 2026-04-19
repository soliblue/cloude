import Foundation
import CloudeShared

extension EnvironmentConnection {
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
        if !runningOutputs.isEmpty {
            handleDisconnect()
        } else {
            resetServerState()
        }

        if clearCredentials {
            savedHost = ""
            savedToken = ""
        }
    }

    func authenticate() {
        AppLogger.connectionInfo("authenticate envId=\(environmentId.uuidString)")
        send(.auth(token: savedToken))
    }

    func checkForMissedResponse() {
        for (sessionId, target) in interruptedSessions {
            let lastSeenSeq = output(for: target.conversationId).lastSeenSeq
            AppLogger.connectionInfo("heuristic_counter=resumeFrom_send sessionId=\(sessionId) lastSeq=\(lastSeenSeq)")
            send(.resumeFrom(sessionId: sessionId, lastSeq: lastSeenSeq))
        }
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

    func sendChat(_ message: String, workingDirectory: String? = nil, sessionId: String? = nil, isNewSession: Bool = true, conversationId: UUID? = nil, imagesBase64: [String]? = nil, filesBase64: [AttachedFilePayload]? = nil, conversationName: String? = nil, forkSession: Bool = false, effort: String? = nil, model: String? = nil) {
        if let convId = conversationId {
            AppLogger.beginInterval("chat.firstToken", key: convId.uuidString, details: "chars=\(message.count)")
            AppLogger.beginInterval("chat.complete", key: convId.uuidString, details: "chars=\(message.count)")
            output(for: convId).reset()
            output(for: convId).phase = .running
        }
        send(.chat(message: message, workingDirectory: workingDirectory ?? defaultWorkingDirectory, sessionId: sessionId, isNewSession: isNewSession, imagesBase64: imagesBase64, filesBase64: filesBase64, conversationId: conversationId?.uuidString, conversationName: conversationName, forkSession: forkSession, effort: effort, model: model))
    }

    func abort(conversationId: UUID? = nil) {
        send(.abort(conversationId: conversationId?.uuidString))
    }

    func syncHistory(sessionId: String, workingDirectory: String) { send(.syncHistory(sessionId: sessionId, workingDirectory: workingDirectory)) }

    func transcribe(audioBase64: String) {
        isTranscribing = true
        send(.transcribe(audioBase64: audioBase64))
    }

    func requestNameSuggestion(text: String, context: [String], conversationId: UUID) {
        send(.suggestName(text: text, context: context, conversationId: conversationId.uuidString))
    }
}
