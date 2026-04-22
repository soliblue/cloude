import Foundation
import SwiftData

enum EndpointActions {
    @MainActor
    @discardableResult
    static func add(into context: ModelContext) -> Endpoint {
        let endpoint = Endpoint(symbolName: EndpointsSymbolCatalog.symbols.randomElement() ?? Endpoint.defaultSymbol)
        context.insert(endpoint)
        return endpoint
    }

    @MainActor
    @discardableResult
    static func create(
        into context: ModelContext, host: String, port: Int, name: String? = nil,
        symbolName: String, authKey: String
    ) -> Endpoint {
        let endpoint = Endpoint(host: host, port: port, name: name, symbolName: symbolName)
        endpoint.lastCheckReachable = true
        endpoint.lastCheckTimestamp = .now
        context.insert(endpoint)
        SecureStorage.set(account: endpoint.id.uuidString, value: authKey)
        return endpoint
    }

    @MainActor
    static func update(
        _ endpoint: Endpoint, host: String, port: Int, name: String? = nil,
        symbolName: String, authKey: String
    ) {
        endpoint.host = host
        endpoint.port = port
        if let name { endpoint.name = name }
        endpoint.symbolName = symbolName
        endpoint.lastCheckReachable = true
        endpoint.lastCheckTimestamp = .now
        SecureStorage.set(account: endpoint.id.uuidString, value: authKey)
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
