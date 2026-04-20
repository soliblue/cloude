import Foundation
import Combine

final class EndpointsStore: ObservableObject {
    @Published var endpoints: [Endpoint] = [] {
        didSet { if isLoaded && endpoints != oldValue { save() } }
    }

    private var isLoaded = false
    private let fileURL: URL = {
        let dir = try! FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return dir.appendingPathComponent("endpoints.json")
    }()

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([Endpoint].self, from: data) {
            endpoints = list
        }
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let token = env["CLOUDE_DEV_TOKEN"],
           let host = env["CLOUDE_DEV_HOST"],
           let portString = env["CLOUDE_DEV_PORT"], let port = Int(portString),
           let idString = env["CLOUDE_DEV_ENV_ID"], let id = UUID(uuidString: idString) {
            SecureStorage.set(account: id.uuidString, value: token)
            let dev = Endpoint(id: id, host: host, port: port, symbolName: "testtube.2")
            if let index = endpoints.firstIndex(where: { $0.id == id }) {
                endpoints[index] = dev
            } else {
                endpoints.append(dev)
            }
        }
        #endif
        isLoaded = true
    }

    private func save() {
        if let data = try? JSONEncoder().encode(endpoints) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func setStatus(id: UUID, _ status: EndpointStatus) {
        if let index = endpoints.firstIndex(where: { $0.id == id }) {
            endpoints[index].status = status
        }
    }
}
