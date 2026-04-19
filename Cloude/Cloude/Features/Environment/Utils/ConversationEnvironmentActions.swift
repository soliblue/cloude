import Foundation

extension App {
    func setActiveConversationEnvironment(id: UUID) {
        if environmentStore.environments.contains(where: { $0.id == id }),
           let conversation = activeConversation() {
            conversationStore.setEnvironmentId(conversation, environmentId: id)
            AppLogger.bootstrapInfo("set conversation environment convId=\(conversation.id.uuidString) envId=\(id.uuidString)")
        } else {
            AppLogger.bootstrapInfo("set conversation environment ignored envId=\(id.uuidString)")
        }
    }
}
