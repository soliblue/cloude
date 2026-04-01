import Foundation

extension App {
    func handleSettingsDeepLink(host: String, url: URL) {
        switch host {
        case "environment":
            if let envId = url.queryValue(named: "id").flatMap(UUID.init(uuidString:)) {
                switch url.path {
                case "/select":
                    selectEnvironment(id: envId)
                case "/connect":
                    connectEnvironment(id: envId)
                case "/disconnect":
                    disconnectEnvironment(id: envId)
                default:
                    break
                }
            }
        case "settings":
            dismissTransientUI()
            settingsStore.isPresented = true
        default:
            break
        }
    }
}
