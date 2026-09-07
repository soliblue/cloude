import Foundation
import SwiftData

enum EndpointActions {
    @MainActor
    @discardableResult
    static func create(
        into context: ModelContext, host: String, port: Int, name: String? = nil,
        symbolName: String, authKey: String, scheme: String? = nil
    ) -> Endpoint {
        let endpoint = Endpoint(host: host, port: port, name: name, symbolName: symbolName, scheme: scheme)
        endpoint.lastCheckReachable = true
        endpoint.lastCheckTimestamp = .now
        context.insert(endpoint)
        SecureStorage.set(account: endpoint.id.uuidString, value: authKey)
        return endpoint
    }

    @MainActor
    static func update(
        _ endpoint: Endpoint, host: String, port: Int, name: String? = nil,
        symbolName: String, authKey: String, scheme: String? = nil
    ) {
        if endpoint.host != host || endpoint.port != port
            || endpoint.transportScheme != (scheme ?? (port == 443 ? "https" : "http"))
            || SecureStorage.get(account: endpoint.id.uuidString) != authKey
        {
            if let context = endpoint.modelContext {
                ChatService.connectionChanged(endpointId: endpoint.id, context: context)
            }
            HTTPClient.invalidate(endpointId: endpoint.id)
            let cacheId = endpoint.cacheId
            endpoint.connectionRevision = UUID()
            endpoint.capabilities = nil
            endpoint.supportsCodex = nil
            endpoint.daemonVersion = nil
            endpoint.daemonPlatform = nil
            endpoint.lastCheckReachable = nil
            endpoint.lastCheckTimestamp = nil
            Task {
                await FileCache.shared.remove(endpoint: cacheId)
                await ScheduleCache.shared.remove(endpoint: cacheId)
                await SessionProjectService.removeCache(endpointId: cacheId)
            }
        }
        endpoint.host = host
        endpoint.port = port
        endpoint.schemeRaw = scheme
        if let name { endpoint.name = name }
        endpoint.symbolName = symbolName
        SecureStorage.set(account: endpoint.id.uuidString, value: authKey)
    }

    @MainActor
    static func setSupportsCodex(_ value: Bool, for endpoint: Endpoint) {
        endpoint.supportsCodex = value
    }

    @MainActor
    static func setCapabilities(_ value: [String], for endpoint: Endpoint) {
        if endpoint.capabilities != value { endpoint.capabilities = value }
    }

    @MainActor
    static func remove(_ endpoint: Endpoint, context: ModelContext) {
        HTTPClient.invalidate(endpointId: endpoint.id)
        SecureStorage.delete(account: endpoint.id.uuidString)
        let endpointId = endpoint.id
        let cacheId = endpoint.cacheId
        Task {
            await FileCache.shared.remove(endpoint: cacheId)
            await ScheduleCache.shared.remove(endpoint: cacheId)
            await SessionProjectService.removeCache(endpointId: cacheId)
            if cacheId != endpointId {
                await FileCache.shared.remove(endpoint: endpointId)
                await ScheduleCache.shared.remove(endpoint: endpointId)
                await SessionProjectService.removeCache(endpointId: endpointId)
            }
        }
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.endpoint?.id == endpointId }
        )
        for session in (try? context.fetch(descriptor)) ?? [] {
            ChatService.detach(sessionId: session.id)
            SessionActions.detachEndpoint(for: session)
        }
        context.delete(endpoint)
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
                existing.schemeRaw = nil
                existing.symbolName = Endpoint.devSymbol
            } else {
                context.insert(Endpoint(id: id, host: host, port: port, symbolName: Endpoint.devSymbol))
            }
        }
        #endif
    }
}
