import Foundation
import Combine
import UIKit
import CloudeShared

@MainActor
class ConnectionManager: ObservableObject {
    @Published var connections: [UUID: EnvironmentConnection] = [:]

    let events = PassthroughSubject<ConnectionEvent, Never>()
    var conversationOutputs: [UUID: ConversationOutput] = [:]
    var conversationEnvironments: [UUID: UUID] = [:]
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    var isConnected: Bool { connections.values.contains { $0.isConnected } }
    var isAuthenticated: Bool { connections.values.contains { $0.isAuthenticated } }

    var agentState: AgentState {
        let states = connections.values.map(\.agentState)
        if states.contains(.running) { return .running }
        if states.contains(.compacting) { return .compacting }
        return .idle
    }

    var isAnyRunning: Bool {
        conversationOutputs.values.contains { $0.isRunning }
    }

    var lastError: String? {
        connections.values.compactMap(\.lastError).first
    }

    var processes: [AgentProcessInfo] {
        connections.values.flatMap(\.processes)
    }

    var skills: [Skill] {
        var seen = Set<String>()
        return connections.values.flatMap(\.skills).filter { seen.insert($0.name).inserted }
    }

    var isWhisperReady: Bool {
        connections.values.contains { $0.isWhisperReady }
    }

    var isTranscribing: Bool {
        connections.values.contains { $0.isTranscribing }
    }

    var defaultWorkingDirectory: String? {
        connections.values.compactMap(\.defaultWorkingDirectory).first
    }

    var chunkProgress: EnvironmentConnection.ChunkProgress? {
        connections.values.compactMap(\.chunkProgress).first
    }

    var fileCache: AggregateFileCache {
        AggregateFileCache(connections: connections)
    }

    func output(for conversationId: UUID) -> ConversationOutput {
        if let existing = conversationOutputs[conversationId] {
            return existing
        }
        let new = ConversationOutput()
        new.parent = self
        conversationOutputs[conversationId] = new
        return new
    }

    func connection(for environmentId: UUID?) -> EnvironmentConnection? {
        environmentId.flatMap { connections[$0] }
    }

    func connectionForConversation(_ conversationId: UUID) -> EnvironmentConnection? {
        conversationEnvironments[conversationId].flatMap { connections[$0] }
    }

    func anyAuthenticatedConnection() -> EnvironmentConnection? {
        connections.values.first { $0.isAuthenticated }
    }

    func connectEnvironment(_ envId: UUID, host: String, port: UInt16, token: String, symbol: String = "laptopcomputer") {
        let conn = connections[envId] ?? EnvironmentConnection(environmentId: envId)
        conn.manager = self
        conn.symbol = symbol
        connections[envId] = conn
        conn.connect(host: host, port: port, token: token)
    }

    func disconnectEnvironment(_ envId: UUID, clearCredentials: Bool = true) {
        connections[envId]?.disconnect(clearCredentials: clearCredentials)
    }

    func disconnectAll(clearCredentials: Bool = true) {
        for conn in connections.values {
            conn.disconnect(clearCredentials: clearCredentials)
        }
    }

    func reconnectAll() {
        for conn in connections.values {
            conn.reconnectIfNeeded()
        }
    }

    func registerConversation(_ conversationId: UUID, environmentId: UUID) {
        conversationEnvironments[conversationId] = environmentId
    }

    func clearAllRunningStates() {
        for output in conversationOutputs.values {
            for i in output.toolCalls.indices where output.toolCalls[i].state == .executing {
                output.toolCalls[i].state = .complete
            }
            output.isRunning = false
            output.isCompacting = false
        }
        for conn in connections.values {
            conn.agentState = .idle
            conn.runningConversationId = nil
        }
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

    func fileCache(for environmentId: UUID?) -> FileCache? {
        environmentId.flatMap { connections[$0]?.fileCache }
    }
}
