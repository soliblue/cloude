import SwiftUI
import CloudeShared
import OSLog

extension App {
    func loadAndConnect() {
        NotificationManager.requestPermission()
        AppLogger.bootstrapInfo("loadAndConnect start envs=\(environmentStore.environments.count)")
        #if DEBUG
        DebugMetrics.log("Bootstrap", "loadAndConnect start envs=\(environmentStore.environments.count)")
        #endif

        let processEnvironment = ProcessInfo.processInfo.environment
        if let host = processEnvironment["CLOUDE_SIM_HOST"],
           let token = processEnvironment["CLOUDE_SIM_TOKEN"],
           !host.isEmpty,
           !token.isEmpty {
            let port = UInt16(processEnvironment["CLOUDE_SIM_PORT"] ?? "") ?? 8765
            let symbol = processEnvironment["CLOUDE_SIM_SYMBOL"] ?? "desktopcomputer"
            let environment = environmentStore.upsertEnvironment(host: host, port: port, token: token, symbol: symbol)
            AppLogger.bootstrapInfo("launch env host=\(host):\(port) envId=\(environment.id.uuidString)")
            #if DEBUG
            DebugMetrics.log("Bootstrap", "launch env host=\(host):\(port) envId=\(environment.id.uuidString.prefix(6))")
            #endif
            connection.connectEnvironment(environment.id, host: environment.host, port: environment.port, token: environment.token, symbol: environment.symbol)
            return
        }

        if let environment = environmentStore.activeEnvironment,
           !environment.host.isEmpty,
           !environment.token.isEmpty {
            AppLogger.bootstrapInfo("saved env host=\(environment.host):\(environment.port) envId=\(environment.id.uuidString)")
            #if DEBUG
            DebugMetrics.log("Bootstrap", "saved env host=\(environment.host):\(environment.port) envId=\(environment.id.uuidString.prefix(6))")
            #endif
            connection.connectEnvironment(environment.id, host: environment.host, port: environment.port, token: environment.token, symbol: environment.symbol)
            return
        }

        if environmentStore.environments.allSatisfy({ $0.host.isEmpty || $0.token.isEmpty }) {
            AppLogger.bootstrapInfo("no configured environment, opening settings")
            #if DEBUG
            DebugMetrics.log("Bootstrap", "no configured environment, opening settings")
            #endif
            showSettings = true
        }
    }

    func connectAllConfiguredEnvironments() {
        for env in environmentStore.environments where !env.host.isEmpty && !env.token.isEmpty {
            connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
        }
    }

    func selectEnvironment(id: UUID) {
        guard environmentStore.environments.contains(where: { $0.id == id }) else {
            AppLogger.bootstrapInfo("select environment failed envId=\(id.uuidString)")
            return
        }
        environmentStore.setActive(id)
        AppLogger.bootstrapInfo("selected environment envId=\(id.uuidString)")
    }

    func connectEnvironment(id: UUID) {
        guard let environment = environmentStore.environments.first(where: { $0.id == id }) else {
            AppLogger.bootstrapInfo("connect environment failed envId=\(id.uuidString)")
            return
        }
        environmentStore.setActive(id)
        connection.connectEnvironment(environment.id, host: environment.host, port: environment.port, token: environment.token, symbol: environment.symbol)
        AppLogger.bootstrapInfo("connect environment envId=\(id.uuidString)")
    }

    func disconnectEnvironment(id: UUID) {
        connection.disconnectEnvironment(id, clearCredentials: false)
        AppLogger.bootstrapInfo("disconnect environment envId=\(id.uuidString)")
    }

    func setActiveConversationEnvironment(id: UUID) {
        guard environmentStore.environments.contains(where: { $0.id == id }),
              let conversation = activeConversation() else {
            AppLogger.bootstrapInfo("set conversation environment ignored envId=\(id.uuidString)")
            return
        }
        conversationStore.setEnvironmentId(conversation, environmentId: id)
        environmentStore.setActive(id)
        AppLogger.bootstrapInfo("set conversation environment convId=\(conversation.id.uuidString) envId=\(id.uuidString)")
    }
}
