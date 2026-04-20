import Foundation
import Combine
import CloudeShared

@MainActor
class Connection: ObservableObject, Identifiable {
    let environmentId: UUID
    let conversationRuntime: EnvironmentConversationRuntime
    let files: FilesAPI
    let git: GitAPI
    let transcription: TranscriptionAPI

    @Published var phase: ConnectionPhase = .disconnected
    @Published var lastError: String?
    @Published var defaultWorkingDirectory: String?
    @Published var skills: [Skill] = []
    @Published var latencyMs: Double?

    var symbol: String = "laptopcomputer"
    var childSubscriptions: Set<AnyCancellable> = []

    var webSocket: URLSessionWebSocketTask?
    var session: URLSession?
    var savedHost: String = ""
    var savedPort: UInt16 = 8765
    var savedToken: String = ""
    var connectionToken = UUID()

    weak var connectionStore: ConnectionStore?

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

    var hasRunningOutputs: Bool {
        conversationRuntime.hasRunningOutputs
    }

    init(environmentId: UUID) {
        self.environmentId = environmentId
        self.conversationRuntime = EnvironmentConversationRuntime(environmentId: environmentId)
        self.files = FilesAPI(environmentId: environmentId)
        self.git = GitAPI(environmentId: environmentId)
        self.transcription = TranscriptionAPI(environmentId: environmentId)
        conversationRuntime.send = { [weak self] message in
            self?.send(message)
        }
        conversationRuntime.resolveDefaultWorkingDirectory = { [weak self] in
            self?.defaultWorkingDirectory
        }
        conversationRuntime.emitEvent = { [weak self] event in
            self?.connectionStore?.events.send(event)
        }
        files.send = { [weak self] message in
            self?.send(message)
        }
        git.send = { [weak self] message in
            self?.send(message)
        }
        git.canSend = { [weak self] in
            self?.isReady == true
        }
        transcription.send = { [weak self] message in
            self?.send(message)
        }
        transcription.emitEvent = { [weak self] event in
            self?.connectionStore?.events.send(event)
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
        transcription.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &childSubscriptions)
    }

    func conversation(_ conversationId: UUID) -> ConversationAPI {
        conversationRuntime.conversation(for: conversationId)
    }

    func resetServerState() {
        phase = .disconnected
        files.reset()
        git.reset()
        transcription.reset()
    }
}
