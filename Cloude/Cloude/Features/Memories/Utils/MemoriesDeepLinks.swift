import Foundation

extension App {
    func handleMemoriesDeepLink(host: String, url: URL) {
        switch host {
        case "memory", "memories":
            dismissTransientUI()
            memoriesStore.open(connection: connection)
        default:
            break
        }
    }
}
