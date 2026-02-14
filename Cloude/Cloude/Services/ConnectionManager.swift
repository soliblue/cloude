import Foundation
import Combine
import UIKit
import CloudeShared

@MainActor
class ConnectionManager: ObservableObject {
    @Published var isConnected = false
    @Published var isAuthenticated = false
    @Published var isWhisperReady = false
    @Published var isKokoroReady = false
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

    let events = PassthroughSubject<ConnectionEvent, Never>()
    var fileCache = FileCache()

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var savedHost: String = ""
    private var savedPort: UInt16 = 8765
    private var savedToken: String = ""
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    // Used to ignore callbacks from stale sockets after reconnect/disconnect.
    private var connectionToken = UUID()
    // Used by `ConnectionManager+API.swift` to serialize git-status requests (result payload has no path).
    // Keep usage limited to the ConnectionManager implementation.
    var gitStatusQueue: [String] = []
    var gitStatusInFlightPath: String?

    var runningConversationId: UUID?
    var conversationOutputs: [UUID: ConversationOutput] = [:]
    var interruptedSession: (conversationId: UUID, sessionId: String, messageId: UUID)?

    var pendingChunks: [String: (chunks: [Int: String], totalChunks: Int, mimeType: String, size: Int64)] = [:]

    func output(for conversationId: UUID) -> ConversationOutput {
        if let existing = conversationOutputs[conversationId] {
            return existing
        }
        let new = ConversationOutput()
        new.parent = self
        conversationOutputs[conversationId] = new
        return new
    }

    var hasCredentials: Bool {
        !savedHost.isEmpty && !savedToken.isEmpty
    }

    var isAnyRunning: Bool {
        conversationOutputs.values.contains { $0.isRunning }
    }

    func clearAllRunningStates() {
        for output in conversationOutputs.values {
            for i in output.toolCalls.indices where output.toolCalls[i].state == .executing {
                output.toolCalls[i].state = .complete
            }
            output.isRunning = false
            output.isCompacting = false
        }
        agentState = .idle
        runningConversationId = nil
    }

    func beginBackgroundStreamingIfNeeded() {
        guard isAnyRunning, backgroundTaskId == .invalid else { return }
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "StreamingResponse") { [weak self] in
            self?.endBackgroundStreaming()
        }
    }

    func endBackgroundStreaming() {
        guard backgroundTaskId != .invalid else { return }
        let taskId = backgroundTaskId
        backgroundTaskId = .invalid
        UIApplication.shared.endBackgroundTask(taskId)
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
        // Clear any in-flight request state that depends on a live socket.
        gitStatusQueue.removeAll()
        gitStatusInFlightPath = nil
        isConnected = false
        isAuthenticated = false
        isWhisperReady = false
        isKokoroReady = false
        isTranscribing = false
        agentState = .idle

        if clearCredentials {
            savedHost = ""
            savedToken = ""
        }
    }

    func receiveMessage() {
        receiveMessage(token: connectionToken)
    }

    private func receiveMessage(token: UUID) {
        webSocket?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard token == self.connectionToken else { return }

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

    func handleDisconnect() {
        if let convId = runningConversationId,
           let output = conversationOutputs[convId] {
            output.flushBuffer()
            for i in output.toolCalls.indices where output.toolCalls[i].state == .executing {
                output.toolCalls[i].state = .complete
            }
            if !output.text.isEmpty {
                events.send(.disconnect(conversationId: convId, output: output))
            }
            output.isRunning = false
        }
        isConnected = false
        isAuthenticated = false
        isWhisperReady = false
        isKokoroReady = false
        isTranscribing = false
        agentState = .idle
        runningConversationId = nil
        gitStatusQueue.removeAll()
        gitStatusInFlightPath = nil
        endBackgroundStreaming()
    }

    func checkForMissedResponse() {
        guard let interrupted = interruptedSession else { return }
        send(.requestMissedResponse(sessionId: interrupted.sessionId))
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
}
