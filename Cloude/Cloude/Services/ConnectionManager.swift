import Foundation
import Combine
import CloudeShared

class ConversationOutput: ObservableObject {
    weak var parent: ConnectionManager?

    @Published var text: String = "" { didSet { parent?.objectWillChange.send() } }
    @Published var toolCalls: [ToolCall] = [] { didSet { parent?.objectWillChange.send() } }
    @Published var runStats: (durationMs: Int, costUsd: Double)? { didSet { parent?.objectWillChange.send() } }
    @Published var isRunning: Bool = false { didSet { parent?.objectWillChange.send() } }
    @Published var newSessionId: String? { didSet { parent?.objectWillChange.send() } }
    var lastSavedMessageId: UUID?

    func reset() {
        text = ""
        toolCalls = []
        runStats = nil
        newSessionId = nil
    }
}

@MainActor
class ConnectionManager: ObservableObject {
    @Published var isConnected = false
    @Published var isAuthenticated = false
    @Published var isWhisperReady = false
    @Published var agentState: AgentState = .idle
    @Published var lastError: String?

    let events = PassthroughSubject<ConnectionEvent, Never>()

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var savedHost: String = ""
    private var savedPort: UInt16 = 8765
    private var savedToken: String = ""

    var runningConversationId: UUID?
    var conversationOutputs: [UUID: ConversationOutput] = [:]
    var interruptedSession: (conversationId: UUID, sessionId: String)?

    var onDirectoryListing: ((String, [FileEntry]) -> Void)?
    var onFileContent: ((String, String, String, Int64) -> Void)?
    var onMissedResponse: ((String, String, Date) -> Void)?
    var onGitStatus: ((GitStatusInfo) -> Void)?
    var onGitDiff: ((String, String) -> Void)?
    var onDisconnect: ((UUID, ConversationOutput) -> Void)?
    var onTranscription: ((String) -> Void)?
    var onHeartbeatConfig: ((Int?, Int, String?) -> Void)?
    var onHeartbeatOutput: ((String) -> Void)?
    var onHeartbeatComplete: ((String) -> Void)?
    var onMemories: (([MemorySection]) -> Void)?

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

    func connect(host: String, port: UInt16, token: String) {
        savedHost = host
        savedPort = port
        savedToken = token
        reconnect()
    }

    func reconnect() {
        guard hasCredentials else { return }
        disconnect(clearCredentials: false)

        guard let url = URL(string: "ws://\(savedHost):\(savedPort)") else {
            lastError = "Invalid URL"
            return
        }

        session = URLSession(configuration: .default)
        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()

        isConnected = true
        lastError = nil

        receiveMessage()
    }

    func reconnectIfNeeded() {
        guard hasCredentials, !isAuthenticated else { return }
        reconnect()
    }

    func disconnect(clearCredentials: Bool = true) {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session = nil
        isConnected = false
        isAuthenticated = false
        isWhisperReady = false
        agentState = .idle

        if clearCredentials {
            savedHost = ""
            savedToken = ""
        }
    }

    func receiveMessage() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
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
                    self.receiveMessage()

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
            if let sessionId = output.newSessionId {
                interruptedSession = (convId, sessionId)
            }
            if !output.text.isEmpty {
                events.send(.disconnect(conversationId: convId, output: output))
                onDisconnect?(convId, output)
            }
            output.isRunning = false
        }
        isConnected = false
        isAuthenticated = false
        isWhisperReady = false
        agentState = .idle
        runningConversationId = nil
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
