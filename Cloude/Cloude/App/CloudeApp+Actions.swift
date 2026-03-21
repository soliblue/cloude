import SwiftUI
import CloudeShared

extension CloudeApp {
    func openMemories() {
        if let cached = OfflineCacheService.loadMemories() {
            memorySections = cached.sections
            memoriesFromCache = true
            isLoadingMemories = connection.isAuthenticated
        } else {
            memorySections = []
            memoriesFromCache = false
            isLoadingMemories = true
        }
        if connection.isAuthenticated {
            connection.send(.getMemories)
        }
        showMemories = true
    }

    func openPlans() {
        if let cached = OfflineCacheService.loadPlans() {
            planStages = cached.stages
            plansFromCache = true
            isLoadingPlans = connection.isAuthenticated
        } else {
            planStages = [:]
            plansFromCache = false
            isLoadingPlans = true
        }
        let activeEnvConn = connection.connection(for: environmentStore.activeEnvironmentId)
        if let wd = windowManager.activeWindow?.conversation(in: conversationStore)?.workingDirectory ?? activeEnvConn?.defaultWorkingDirectory {
            connection.getPlans(workingDirectory: wd)
        }
        showPlans = true
    }

    func loadAndConnect() {
        NotificationManager.requestPermission()

        if environmentStore.environments.allSatisfy({ $0.host.isEmpty || $0.token.isEmpty }) {
            showSettings = true
        }
    }

    func connectAllConfiguredEnvironments() {
        for env in environmentStore.environments where !env.host.isEmpty && !env.token.isEmpty {
            connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
        }
    }
}
