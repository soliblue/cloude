import Foundation
import Combine
import CloudeShared

@MainActor
class EnvironmentConnection: ObservableObject, Identifiable {
    let environmentId: UUID
    let files: FilesRuntime
    let git: GitRuntime

    @Published var phase: ConnectionPhase = .disconnected
    @Published var isWhisperReady = false
    @Published var isTranscribing = false
    @Published var agentState: AgentState = .idle
    @Published var lastError: String?
    @Published var defaultWorkingDirectory: String?
    @Published var skills: [Skill] = []
    @Published var latencyMs: Double?

    var symbol: String = "laptopcomputer"
    var childSubscriptions: Set<AnyCancellable> = []
    var interruptedSessions: [String: InterruptedSession] = [:]
    var conversationOutputs: [UUID: ConversationOutput] = [:]

    var webSocket: URLSessionWebSocketTask?
    var session: URLSession?
    var savedHost: String = ""
    var savedPort: UInt16 = 8765
    var savedToken: String = ""
    var connectionToken = UUID()

    weak var manager: EnvironmentStore?

    var id: UUID { environmentId }

    var hasCredentials: Bool {
        !savedHost.isEmpty && !savedToken.isEmpty
    }

    var isReady: Bool {
        phase == .authenticated
    }

    var isConnecting: Bool {
        phase == .connected
    }

    var runningOutputs: [(conversationId: UUID, output: ConversationOutput)] {
        conversationOutputs.compactMap { (convId, output) in
            output.phase != .idle ? (convId, output) : nil
        }
    }

    init(environmentId: UUID) {
        self.environmentId = environmentId
        self.files = FilesRuntime(environmentId: environmentId)
        self.git = GitRuntime(environmentId: environmentId)
        files.send = { [weak self] message in
            self?.send(message)
        }
        git.send = { [weak self] message in
            self?.send(message)
        }
        git.canSend = { [weak self] in
            self?.isReady == true
        }
        files.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &childSubscriptions)
        git.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &childSubscriptions)
    }

    func output(for conversationId: UUID) -> ConversationOutput {
        if let existing = conversationOutputs[conversationId] {
            return existing
        }
        let new = ConversationOutput()
        conversationOutputs[conversationId] = new
        return new
    }

    func resetServerState() {
        phase = .disconnected
        isWhisperReady = false
        isTranscribing = false
        agentState = .idle
        files.reset()
        git.reset()
    }

    func ensureRunning(_ out: ConversationOutput) {
        if out.phase == .idle { out.phase = .running }
    }
}
