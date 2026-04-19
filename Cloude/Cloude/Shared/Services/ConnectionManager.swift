import Foundation
import Combine
import UIKit
import CloudeShared
import OSLog

@MainActor
class ConnectionManager: ObservableObject {
    @Published var connections: [UUID: EnvironmentConnection] = [:]

    let events = PassthroughSubject<ConnectionEvent, Never>()
    var conversationOutputs: [UUID: ConversationOutput] = [:]
    var conversationEnvironments: [UUID: UUID] = [:]
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    var isAnyAuthenticated: Bool { connections.values.contains { $0.phase == .authenticated } }

    var isAnyRunning: Bool {
        conversationOutputs.values.contains { $0.phase != .idle }
    }

    var processes: [AgentProcessInfo] {
        connections.values.flatMap(\.processes)
    }

    var skills: [Skill] {
        var seen = Set<String>()
        return connections.values.flatMap(\.skills).filter { seen.insert($0.name).inserted }
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
        connections.values.first { $0.phase == .authenticated }
    }

    func connectEnvironment(_ envId: UUID, host: String, port: UInt16, token: String, symbol: String = "laptopcomputer") {
        AppLogger.connectionInfo("connectEnvironment envId=\(envId.uuidString) host=\(host):\(port)")
        let conn = connections[envId] ?? EnvironmentConnection(environmentId: envId)
        conn.manager = self
        conn.symbol = symbol
        connections[envId] = conn
        conn.connect(host: host, port: port, token: token)
    }

    func disconnectEnvironment(_ envId: UUID, clearCredentials: Bool = true) {
        connections[envId]?.disconnect(clearCredentials: clearCredentials)
    }

    func reconnectAll() {
        for conn in connections.values {
            conn.reconnectIfNeeded()
        }
    }

    func registerConversation(_ conversationId: UUID, environmentId: UUID) {
        conversationEnvironments[conversationId] = environmentId
    }

    func runningOutputs(for environmentId: UUID) -> [(conversationId: UUID, output: ConversationOutput)] {
        conversationOutputs.compactMap { (convId, output) in
            output.phase != .idle && conversationEnvironments[convId] == environmentId ? (convId, output) : nil
        }
    }

    func handleForegroundTransition() {
        for conn in connections.values {
            if !runningOutputs(for: conn.environmentId).isEmpty { conn.handleDisconnect() }
            if conn.hasCredentials { conn.reconnect() }
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
}
