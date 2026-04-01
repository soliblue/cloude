import Foundation

extension App {
    func handleWhiteboardDeepLink(host: String, url: URL) {
        switch host {
        case "whiteboard":
            dismissTransientUI()
            if url.path == "/snapshot" {
                handleWhiteboardAction(action: "snapshot", json: [:], conversationId: nil)
            } else if url.path == "/export" {
                handleWhiteboardAction(action: "export", json: [:], conversationId: nil)
            } else {
                whiteboardStore.present(conversationId: windowManager.activeWindow?.conversation(in: conversationStore)?.id)
            }
        default:
            break
        }
    }
}
