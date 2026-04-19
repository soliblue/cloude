import Foundation
import Combine
import CloudeShared

@MainActor
class EnvironmentStore: ObservableObject {
    @Published var environments: [ServerEnvironment] = []
    @Published var activeEnvironmentId: UUID?
    @Published var connections: [UUID: EnvironmentConnection] = [:]
    let events = PassthroughSubject<ConnectionEvent, Never>()

    var activeEnvironment: ServerEnvironment? {
        environments.first { $0.id == activeEnvironmentId }
    }

    func connection(for environmentId: UUID?) -> EnvironmentConnection? {
        environmentId.flatMap { connections[$0] }
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

    func isStreaming(for conversation: Conversation) -> Bool {
        (connection(for: conversation.environmentId)?.output(for: conversation.id).phase ?? .idle) != .idle
    }

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("environments.json")
    }

    init() {
        load()
    }

    func load() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([ServerEnvironment].self, from: data) {
            environments = saved
            if let savedId = UserDefaults.standard.string(forKey: "activeEnvironmentId") {
                activeEnvironmentId = UUID(uuidString: savedId)
            }
            if activeEnvironment == nil, let first = environments.first {
                setActive(first.id)
            }
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(environments) {
            try? data.write(to: Self.fileURL)
        }
    }

    func add(_ env: ServerEnvironment) {
        environments.append(env)
        if environments.count == 1 {
            setActive(env.id)
        }
        save()
    }

    func update(_ env: ServerEnvironment) {
        if let idx = environments.firstIndex(where: { $0.id == env.id }) {
            environments[idx] = env
            save()
        }
    }

    func delete(_ envId: UUID) {
        if let connection = connections.removeValue(forKey: envId) {
            connection.disconnect()
        }
        environments.removeAll { $0.id == envId }
        if activeEnvironmentId == envId {
            activeEnvironmentId = environments.first?.id
            UserDefaults.standard.set(activeEnvironmentId?.uuidString, forKey: "activeEnvironmentId")
        }
        save()
    }

    func setActive(_ envId: UUID) {
        activeEnvironmentId = envId
        UserDefaults.standard.set(envId.uuidString, forKey: "activeEnvironmentId")
    }

    func upsertEnvironment(host: String, port: UInt16, token: String, symbol: String = "desktopcomputer") -> ServerEnvironment {
        if let index = environments.firstIndex(where: { $0.host == host && $0.port == port }) {
            environments[index].token = token
            environments[index].symbol = symbol
            save()
            setActive(environments[index].id)
            return environments[index]
        }

        let environment = ServerEnvironment(host: host, port: port, token: token, symbol: symbol)
        environments.append(environment)
        save()
        setActive(environment.id)
        return environment
    }
}
