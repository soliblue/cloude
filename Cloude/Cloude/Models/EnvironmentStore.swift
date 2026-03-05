import Foundation
import Combine

@MainActor
class EnvironmentStore: ObservableObject {
    @Published var environments: [ServerEnvironment] = []
    @Published var activeEnvironmentId: UUID?

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
            return
        }

        migrateFromLegacy()
    }

    private func migrateFromLegacy() {
        let host = UserDefaults.standard.string(forKey: "serverHost") ?? ""
        let port = UInt16(UserDefaults.standard.string(forKey: "serverPort") ?? "8765") ?? 8765
        let token = KeychainHelper.get(key: "authToken") ?? ""

        if !host.isEmpty || !token.isEmpty {
            let env = ServerEnvironment(name: "Default", host: host, port: port, token: token)
            environments = [env]
            setActive(env.id)
            save()
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
}
