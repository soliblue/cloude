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
    @Published var isTranscribing = false { didSet { if isTranscribing != oldValue { manager?.objectWillChange.send() } } }
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

    var webSocket: URLSessionWebSocketTask?
    var session: URLSession?
    var savedHost: String = ""
    var savedPort: UInt16 = 8765
    var savedToken: String = ""
    var connectionToken = UUID()

    weak var manager: ConnectionManager?

    init(environmentId: UUID) {
        self.environmentId = environmentId
    }

    var hasCredentials: Bool {
        !savedHost.isEmpty && !savedToken.isEmpty
    }
}
