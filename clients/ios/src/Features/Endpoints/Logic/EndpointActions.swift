import Foundation
import SwiftData

enum EndpointActions {
    @MainActor
    static func add(into context: ModelContext) {
        context.insert(Endpoint())
    }

    @MainActor
    static func remove(_ endpoint: Endpoint, context: ModelContext) {
        SecureStorage.delete(account: endpoint.id.uuidString)
        context.delete(endpoint)
    }

    @MainActor
    static func saveAuthKey(for endpoint: Endpoint, _ key: String) {
        if !endpoint.isDeleted {
            SecureStorage.set(account: endpoint.id.uuidString, value: key)
        }
    }

    @MainActor
    static func seedDev(context: ModelContext) {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let token = env["CLOUDE_DEV_TOKEN"],
            let host = env["CLOUDE_DEV_HOST"],
            let portString = env["CLOUDE_DEV_PORT"], let port = Int(portString),
            let idString = env["CLOUDE_DEV_ENV_ID"], let id = UUID(uuidString: idString)
        {
            SecureStorage.set(account: id.uuidString, value: token)
            let fetch = FetchDescriptor<Endpoint>(predicate: #Predicate { $0.id == id })
            if let existing = (try? context.fetch(fetch))?.first {
                existing.host = host
                existing.port = port
                existing.symbolName = Endpoint.devSymbol
            } else {
                context.insert(Endpoint(id: id, host: host, port: port, symbolName: Endpoint.devSymbol))
            }
        }
        #endif
    }
}
