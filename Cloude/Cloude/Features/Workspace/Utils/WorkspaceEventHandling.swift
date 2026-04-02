import Foundation

extension App {
    func handleDefaultWorkingDirectory(path: String, environmentId: UUID?) {
        plansStore.handleDefaultWorkingDirectory(path, environmentId: environmentId, connection: connection)
    }

    func handleSwitchConversation(conversationId: UUID) {
        if let conversation = conversationStore.findConversation(withId: conversationId) {
            let targetId = windowManager.activeWindowId ?? windowManager.windows.first?.id
            if let targetId {
                windowManager.linkToCurrentConversation(targetId, conversation: conversation)
            }
        }
    }
}
