import Foundation

extension App {
    func connectEnvironment(env: ServerEnvironment) {
        environmentStore.setActive(env.id)
        connection.connectEnvironment(env.id, host: env.host, port: env.port, token: env.token, symbol: env.symbol)
        AppLogger.bootstrapInfo("connect environment envId=\(env.id.uuidString)")
    }

    func connectEnvironment(id: UUID) {
        if let environment = environmentStore.environments.first(where: { $0.id == id }) {
            connectEnvironment(env: environment)
        } else {
            AppLogger.bootstrapInfo("connect environment failed envId=\(id.uuidString)")
        }
    }

    func disconnectEnvironment(id: UUID) {
        connection.disconnectEnvironment(id, clearCredentials: false)
        AppLogger.bootstrapInfo("disconnect environment envId=\(id.uuidString)")
    }
}
