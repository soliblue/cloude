import Foundation
import CloudeShared

extension Window {
    func runtimeContext(conversationStore: ConversationStore, environmentStore: EnvironmentStore) -> WindowRuntimeContext {
        let conversation = conversation(in: conversationStore)
        let environmentId = runtimeEnvironmentId(conversationStore: conversationStore, environmentStore: environmentStore)
            ?? environmentStore.activeEnvironmentId
        let environment = environmentStore.environments.first { $0.id == environmentId }
        let connection = environmentStore.connection(for: environmentId)
        let workingDirectory = conversation?.workingDirectory ?? connection?.defaultWorkingDirectory?.nilIfEmpty
        return WindowRuntimeContext(
            conversation: conversation,
            environmentId: environmentId,
            environment: environment,
            connection: connection,
            workingDirectory: workingDirectory
        )
    }
}
