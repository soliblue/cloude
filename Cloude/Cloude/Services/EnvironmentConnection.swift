import Foundation
import Combine
import UIKit
import CloudeShared

@MainActor
class EnvironmentConnection: ObservableObject, Identifiable {
    let environmentId: UUID
    var symbol: String = "laptopcomputer"

    @Published var isConnected = false
    @Published var isAuthenticated = false
    @Published var isWhisperReady = false
    @Published var isTranscribing = false
    @Published var agentState: AgentState = .idle
    @Published var lastError: String?
    @Published var processes: [AgentProcessInfo] = []
    @Published var defaultWorkingDirectory: String?
    @Published var skills: [Skill] = []
    @Published var chunkProgress: ChunkProgress?

    struct ChunkProgress: Equatable {
        let path: String
        let current: Int
        let total: Int
    }

    var id: UUID { environmentId }
    var runningConversationId: UUID?
    var gitStatusQueue: [String] = []
    var gitStatusInFlightPath: String?
    var gitStatusTimeoutTask: Task<Void, Never>?
    var fileCache = FileCache()
    var pendingChunks: [String: (chunks: [Int: String], totalChunks: Int, mimeType: String, size: Int64)] = [:]
    var interruptedSession: (conversationId: UUID, sessionId: String, messageId: UUID)?

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var savedHost: String = ""
    private var savedPort: UInt16 = 8765
    private var savedToken: String = ""
    private var connectionToken = UUID()

    weak var manager: ConnectionManager?

    init(environmentId: UUID) {
        self.environmentId = environmentId
    }

    var hasCredentials: Bool {
        !savedHost.isEmpty && !savedToken.isEmpty
    }

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

        guard let url = URL(string: "ws://\(savedHost):\(savedPort)") else {
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

    private func receiveMessage(token: UUID) {
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
