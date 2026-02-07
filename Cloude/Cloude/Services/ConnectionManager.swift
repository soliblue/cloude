import Foundation
import Combine
import QuartzCore
import CloudeShared

class ConversationOutput: ObservableObject {
    weak var parent: ConnectionManager?

    @Published var text: String = "" { didSet { if text != oldValue { parent?.objectWillChange.send() } } }
    @Published var toolCalls: [ToolCall] = [] { didSet { parent?.objectWillChange.send() } }
    @Published var runStats: (durationMs: Int, costUsd: Double)? { didSet { parent?.objectWillChange.send() } }
    @Published var isRunning: Bool = false { didSet { if isRunning != oldValue { parent?.objectWillChange.send() } } }
    @Published var isCompacting: Bool = false { didSet { if isCompacting != oldValue { parent?.objectWillChange.send() } } }
    @Published var newSessionId: String? { didSet { if newSessionId != oldValue { parent?.objectWillChange.send() } } }
    @Published var skipped: Bool = false { didSet { if skipped != oldValue { parent?.objectWillChange.send() } } }
    @Published var teamName: String? { didSet { if teamName != oldValue { parent?.objectWillChange.send() } } }
    @Published var teammates: [TeammateInfo] = [] { didSet { parent?.objectWillChange.send() } }
    var lastSavedMessageId: UUID?
    var messageUUID: String?

    var fullText: String = ""
    private var displayIndex: String.Index?
    private var displayLink: CADisplayLink?
    private var lastDrainTime: CFTimeInterval = 0
    private let charsPerSecond: Double = 300

    func appendText(_ chunk: String) {
        fullText += chunk
        startDraining()
    }

    private func startDraining() {
        guard displayLink == nil else { return }
        if displayIndex == nil {
            displayIndex = fullText.startIndex
        }
        lastDrainTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(drainTick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func drainTick() {
        guard let idx = displayIndex, idx < fullText.endIndex else {
            stopDraining()
            return
        }

        let now = CACurrentMediaTime()
        let elapsed = now - lastDrainTime
        lastDrainTime = now

        let buffered = fullText.distance(from: idx, to: fullText.endIndex)
        let rate: Double
        if buffered > 800 {
            rate = charsPerSecond * 4
        } else if buffered > 400 {
            rate = charsPerSecond * 2
        } else {
            rate = charsPerSecond
        }

        var charsToShow = max(1, Int(rate * elapsed))

        var newIdx = idx
        while charsToShow > 0 && newIdx < fullText.endIndex {
            newIdx = fullText.index(after: newIdx)
            charsToShow -= 1
        }

        displayIndex = newIdx
        text = String(fullText[fullText.startIndex..<newIdx])
    }

    private func stopDraining() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func flushBuffer() {
        stopDraining()
        if !fullText.isEmpty {
            text = fullText
            displayIndex = fullText.endIndex
        }
    }

    func reset() {
        stopDraining()
        fullText = ""
        displayIndex = nil
        text = ""
        toolCalls = []
        runStats = nil
        newSessionId = nil
        messageUUID = nil
        isCompacting = false
        skipped = false
        teamName = nil
        teammates = []
    }
}

@MainActor
class ConnectionManager: ObservableObject {
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

    let events = PassthroughSubject<ConnectionEvent, Never>()

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var savedHost: String = ""
    private var savedPort: UInt16 = 8765
    private var savedToken: String = ""

    var runningConversationId: UUID?
    var conversationOutputs: [UUID: ConversationOutput] = [:]
    var interruptedSession: (conversationId: UUID, sessionId: String, messageId: UUID)?

    var onDirectoryListing: ((String, [FileEntry]) -> Void)?
    var onFileContent: ((String, String, String, Int64, Bool) -> Void)?
    var pendingChunks: [String: (chunks: [Int: String], totalChunks: Int, mimeType: String, size: Int64)] = [:]
    var onMissedResponse: ((String, String, [ToolCall], Date, UUID?, UUID?) -> Void)?
    var onGitStatus: ((GitStatusInfo) -> Void)?
    var onGitDiff: ((String, String) -> Void)?
    var onDisconnect: ((UUID, ConversationOutput) -> Void)?
    var onAuthenticated: (() -> Void)?
    var onTranscription: ((String) -> Void)?
    var onHeartbeatConfig: ((Int?, Int) -> Void)?
    var onMemories: (([MemorySection]) -> Void)?
    var onMemoryAdded: ((String, String, String) -> Void)?
    var onRenameConversation: ((UUID, String) -> Void)?
    var onSetConversationSymbol: ((UUID, String?) -> Void)?
    var onSessionIdReceived: ((UUID, String) -> Void)?
    var onProcessList: (([AgentProcessInfo]) -> Void)?
    var onSkills: (([Skill]) -> Void)?
    var onHistorySync: ((String, [HistoryMessage]) -> Void)?
    var onHistorySyncError: ((String, String) -> Void)?
    var onHeartbeatSkipped: ((String?) -> Void)?
    var onDeleteConversation: ((UUID) -> Void)?
    var onNotify: ((String?, String) -> Void)?
    var onClipboard: ((String) -> Void)?
    var onOpenURL: ((String) -> Void)?
    var onHaptic: ((String) -> Void)?
    var onSpeak: ((String) -> Void)?
    var onSwitchConversation: ((UUID) -> Void)?
    var onQuestion: (([Question], UUID?) -> Void)?
    var onScreenshot: ((UUID?) -> Void)?
    var onFileSearchResults: (([String], String) -> Void)?
    var onRemoteSessionList: (([RemoteSession]) -> Void)?
    var onLastAssistantMessageCostUpdate: ((UUID, Double) -> Void)?
    var onAutocompleteResult: ((String, String) -> Void)?
    var onPlans: (([String: [PlanItem]]) -> Void)?
    var onPlanDeleted: ((String, String) -> Void)?

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
            output.isRunning = false
            output.isCompacting = false
        }
        agentState = .idle
        runningConversationId = nil
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
        isTranscribing = false
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
            output.flushBuffer()
            if !output.text.isEmpty {
                events.send(.disconnect(conversationId: convId, output: output))
                onDisconnect?(convId, output)
            }
            output.isRunning = false
        }
        isConnected = false
        isAuthenticated = false
        isWhisperReady = false
        isTranscribing = false
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
