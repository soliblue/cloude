import Foundation

extension App {
    func selectEnvironment(id: UUID) {
        if environmentStore.environments.contains(where: { $0.id == id }) {
            environmentStore.setActive(id)
            AppLogger.bootstrapInfo("selected environment envId=\(id.uuidString)")
        } else {
            AppLogger.bootstrapInfo("select environment failed envId=\(id.uuidString)")
        }
    }

    func connectEnvironment(id: UUID) {
        if let environment = environmentStore.environments.first(where: { $0.id == id }) {
            environmentStore.setActive(id)
            connection.connectEnvironment(environment.id, host: environment.host, port: environment.port, token: environment.token, symbol: environment.symbol)
            AppLogger.bootstrapInfo("connect environment envId=\(id.uuidString)")
        } else {
            AppLogger.bootstrapInfo("connect environment failed envId=\(id.uuidString)")
        }
    }

    func disconnectEnvironment(id: UUID) {
        connection.disconnectEnvironment(id, clearCredentials: false)
        AppLogger.bootstrapInfo("disconnect environment envId=\(id.uuidString)")
    }
}
