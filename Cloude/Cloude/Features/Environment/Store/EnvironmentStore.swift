import Combine
import Foundation
import CloudeShared

@MainActor
class EnvironmentStore: ObservableObject {
    @Published var environments: [ServerEnvironment] = []
    @Published var activeEnvironmentId: UUID?
    let connectionStore = ConnectionStore()

    var activeEnvironment: ServerEnvironment? {
        environments.first { $0.id == activeEnvironmentId }
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
        connectionStore.removeConnection(envId)
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
