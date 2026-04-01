import Foundation

extension App {
    func handlePlansDeepLink(host: String, url: URL) {
        switch host {
        case "plans":
            dismissTransientUI()
            plansStore.initialStage = url.queryValue(named: "stage")
            plansStore.open(
                connection: connection,
                windowManager: windowManager,
                conversationStore: conversationStore,
                environmentStore: environmentStore
            )
        default:
            break
        }
    }
}
