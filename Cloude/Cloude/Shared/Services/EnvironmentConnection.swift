import Foundation
import Combine
import CloudeShared

@MainActor
class EnvironmentConnection: ObservableObject, Identifiable {
    let environmentId: UUID
    var symbol: String = "laptopcomputer"

    @Published var phase: ConnectionPhase = .disconnected { didSet { if phase != oldValue { manager?.objectWillChange.send() } } }
    @Published var isWhisperReady = false
    @Published var isTranscribing = false { didSet { if isTranscribing != oldValue { manager?.objectWillChange.send() } } }
    @Published var agentState: AgentState = .idle
    @Published var lastError: String?
    @Published var processes: [AgentProcessInfo] = [] { didSet { if processes.map(\.pid) != oldValue.map(\.pid) { manager?.objectWillChange.send() } } }
    @Published var defaultWorkingDirectory: String?
    @Published var skills: [Skill] = []
    @Published var chunkProgress: ChunkProgress?
    @Published var latencyMs: Double?

    struct ChunkProgress: Equatable {
        let path: String
        let current: Int
        let total: Int
    }

    var id: UUID { environmentId }
    let gitStatus = GitStatusService()
    var fileCache = FileCache()
    var pendingChunks: [String: PendingChunk] = [:]
    var interruptedSessions: [String: InterruptedSession] = [:]

    var webSocket: URLSessionWebSocketTask?
    var session: URLSession?
    var savedHost: String = ""
    var savedPort: UInt16 = 8765
    var savedToken: String = ""
    var connectionToken = UUID()

    weak var manager: ConnectionManager?

    init(environmentId: UUID) {
        self.environmentId = environmentId
        gitStatus.send = { [weak self] path in
            self?.send(.gitStatus(path: path))
        }
        gitStatus.canSend = { [weak self] in
            self?.phase == .authenticated
        }
    }

    var hasCredentials: Bool {
        !savedHost.isEmpty && !savedToken.isEmpty
    }

    func resetServerState() {
        phase = .disconnected
        isWhisperReady = false
        isTranscribing = false
        agentState = .idle
        gitStatus.reset()
    }
}
